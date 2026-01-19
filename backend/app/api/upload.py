"""
API endpoints for file upload to knowledge bases.
"""

import os
import tempfile
from fastapi import APIRouter, HTTPException, Header, UploadFile, File
from typing import List
from sqlalchemy import create_engine, text
from app.config.settings import settings
from app.extractors import is_supported, extract_text, ALL_EXTENSIONS
from app.utils.chunking import chunk_text, ChunkingConfig

router = APIRouter(prefix="/api/kb", tags=["upload"])

# Max file size: 200MB
MAX_FILE_SIZE = 200 * 1024 * 1024

# Threshold for chunking (files larger than this will be chunked)
CHUNK_THRESHOLD = 2000  # Characters


def get_user_permission_for_kb(user_id: str, user_groups: List[str], kb_group: str) -> str | None:
    """Get user's permission level for a specific KB."""
    if kb_group in user_groups:
        permission = "READ"
    else:
        permission = None
    
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT permission 
                FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions
                WHERE user_id = :user_id AND group_name = :group_name
                ORDER BY CASE permission WHEN 'WRITE' THEN 1 ELSE 2 END
                LIMIT 1
            """),
            {"user_id": user_id, "group_name": kb_group}
        ).fetchone()
        
        if result:
            if result[0] == "WRITE":
                permission = "WRITE"
            elif permission is None:
                permission = result[0]
    
    return permission


def get_kb_by_id(kb_id: str):
    """Get KB details by ID."""
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT id, name, slug, group_name 
                FROM {settings.DB_APP_SCHEMA}.knowledge_bases 
                WHERE id = :id
            """),
            {"id": kb_id}
        ).fetchone()
        
        if result:
            return {
                "id": str(result[0]),
                "name": result[1],
                "slug": result[2],
                "group_name": result[3],
            }
        return None


@router.post("/{kb_id}/upload")
async def upload_file(
    kb_id: str,
    file: UploadFile = File(...),
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Upload a file to the knowledge base.
    
    Supported formats:
    - Documents: PDF, Word (.docx)
    - Text: Plain text (.txt), Markdown (.md)
    - Code: Python, JavaScript, TypeScript, C, C++, Rust, Go, Java, HTML, CSS, etc.
    
    Requires WRITE permission.
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    # ADMIN cannot upload documents
    if "ADMIN" in user_roles and "USER" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role does not grant access to documents")
    
    # Check KB exists
    kb = get_kb_by_id(kb_id)
    if not kb:
        raise HTTPException(status_code=404, detail="Knowledge base not found")
    
    # Check permission
    permission = get_user_permission_for_kb(x_user_id, user_groups, kb["group_name"])
    if permission != "WRITE":
        raise HTTPException(status_code=403, detail="WRITE permission required")
    
    # Validate file
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")
    
    if not is_supported(file.filename):
        supported = ", ".join(sorted(ALL_EXTENSIONS))
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported file type. Supported: {supported}"
        )
    
    # Read file content
    content = await file.read()
    
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400, 
            detail=f"File too large. Maximum size: {MAX_FILE_SIZE // (1024*1024)}MB"
        )
    
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    
    # Save to temp file and extract text
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        
        text_content, metadata = extract_text(tmp_path, file.filename)
        
        if not text_content.strip():
            raise HTTPException(status_code=400, detail="No text content could be extracted from file")
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error processing file: {str(e)}")
    finally:
        # Clean up temp file
        if 'tmp_path' in locals():
            os.unlink(tmp_path)
    
    # Add to knowledge base with chunking for large files
    try:
        from app.knowledge.base import get_knowledge_base
        from app.config.embedders import get_embedder

        embedder, _, _ = get_embedder()
        knowledge = get_knowledge_base(embedder=embedder)

        # Determine if chunking is needed
        chunks_added = 0
        if len(text_content) > CHUNK_THRESHOLD:
            # Use chunking for large files
            chunking_config = ChunkingConfig(
                chunk_size=settings.CHUNK_SIZE,
                chunk_overlap=settings.CHUNK_OVERLAP,
                min_chunk_size=settings.CHUNK_MIN_SIZE,
            )
            chunks = chunk_text(text_content, chunking_config)

            for chunk in chunks:
                chunk_name = f"{file.filename} [chunk {chunk.chunk_index + 1}/{chunk.total_chunks}]"
                knowledge.add_content(
                    text_content=chunk.content,
                    name=chunk_name,
                    metadata={
                        **metadata,
                        "knowledge_base_id": kb_id,
                        "added_by": x_user_id,
                        "chunk_index": chunk.chunk_index,
                        "total_chunks": chunk.total_chunks,
                        "parent_filename": file.filename,
                    },
                )
                chunks_added += 1
        else:
            # Small file: add as single document
            knowledge.add_content(
                text_content=text_content,
                name=file.filename,
                metadata={
                    **metadata,
                    "knowledge_base_id": kb_id,
                    "added_by": x_user_id,
                },
            )
            chunks_added = 1

        # Update knowledge_base_id in embeddings table
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            conn.execute(
                text(f"""
                    UPDATE {settings.DB_APP_SCHEMA}.knowledge_embeddings
                    SET knowledge_base_id = :kb_id
                    WHERE knowledge_base_id IS NULL
                """),
                {"kb_id": kb_id}
            )
            conn.commit()

        # Add chunking info to metadata
        metadata["chunks_created"] = chunks_added

        return {
            "status": "success",
            "message": f"File '{file.filename}' uploaded and processed ({chunks_added} chunk(s))",
            "metadata": metadata,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error adding to knowledge base: {str(e)}")


@router.get("/supported-formats")
async def get_supported_formats():
    """Get list of supported file formats."""
    return {
        "formats": {
            "documents": sorted(list({'.pdf', '.docx'})),
            "text": sorted(list({'.txt', '.md'})),
            "code": sorted(list({
                '.py', '.js', '.ts', '.tsx', '.jsx',
                '.c', '.cpp', '.h', '.hpp', '.rs', '.go', '.java',
                '.html', '.css', '.scss', '.json', '.yaml', '.yml',
                '.sql', '.sh', '.bash', '.zsh',
                '.xml', '.toml', '.ini', '.env',
            })),
        },
        "max_size_mb": MAX_FILE_SIZE // (1024 * 1024),
    }
