"""
API endpoints for knowledge base documents management.
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from sqlalchemy import create_engine, text
from app.config.settings import settings

router = APIRouter(prefix="/api/kb", tags=["documents"])


class AddDocumentRequest(BaseModel):
    """Request to add a document to knowledge base."""
    content: str
    name: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


class SearchRequest(BaseModel):
    """Request to search knowledge base."""
    query: str
    limit: int = 5


class BatchDeleteRequest(BaseModel):
    """Request to delete multiple documents."""
    document_ids: List[str]


def get_user_permission_for_kb(
    user_id: str,
    user_groups: List[str],
    kb_group: Optional[str],
    kb_owner_user_id: Optional[str] = None,
) -> Optional[str]:
    """
    Get user's permission level for a specific KB.
    Returns: 'WRITE', 'READ', or None

    - Personal KB owner has WRITE permission
    - Group member has implicit READ
    - Explicit permissions in DB override
    """
    # Personal KB: owner has WRITE
    if kb_owner_user_id is not None:
        if kb_owner_user_id == user_id:
            return "WRITE"
        else:
            return None  # Others cannot access personal KB

    # Group KB: check group membership (implicit READ)
    if kb_group and kb_group in user_groups:
        permission = "READ"
    else:
        permission = None

    # Check explicit permissions in DB
    if kb_group:
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            result = conn.execute(
                text(f"""
                    SELECT permission
                    FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions
                    WHERE user_id = :user_id AND group_name = :group_name
                    ORDER BY
                        CASE permission WHEN 'WRITE' THEN 1 ELSE 2 END
                    LIMIT 1
                """),
                {"user_id": user_id, "group_name": kb_group}
            ).fetchone()

            if result:
                # WRITE from DB overrides implicit READ
                if result[0] == "WRITE":
                    permission = "WRITE"
                elif permission is None:
                    # Cross-group READ
                    permission = result[0]

    return permission


def get_kb_by_id(kb_id: str):
    """Get KB details by ID."""
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT id, name, slug, group_name, owner_user_id
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
                "owner_user_id": result[4],
                "is_personal": result[4] is not None,
            }
        return None


@router.get("/{kb_id}/documents")
async def list_documents(
    kb_id: str,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    List documents in a knowledge base.
    Requires READ permission (group member or explicit permission).
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    # ADMIN cannot access documents
    if "ADMIN" in user_roles and "USER" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role does not grant access to documents")
    
    kb = get_kb_by_id(kb_id)
    if not kb:
        raise HTTPException(status_code=404, detail="Knowledge base not found")

    permission = get_user_permission_for_kb(
        x_user_id, user_groups, kb["group_name"], kb.get("owner_user_id")
    )
    if not permission:
        raise HTTPException(status_code=403, detail="No access to this knowledge base")

    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT id, name, content, meta_data, created_at
                FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings
                WHERE knowledge_base_id = :kb_id
                ORDER BY created_at DESC
            """),
            {"kb_id": kb_id}
        )
        
        documents = []
        for row in result:
            documents.append({
                "id": str(row[0]),
                "name": row[1],
                "content": row[2][:200] + "..." if row[2] and len(row[2]) > 200 else row[2],
                "metadata": row[3],
                "created_at": str(row[4]) if row[4] else None,
            })
        
        return {
            "status": "success",
            "knowledge_base": kb["name"],
            "permission": permission,
            "documents": documents,
        }


@router.post("/{kb_id}/documents")
async def add_document(
    kb_id: str,
    request: AddDocumentRequest,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Add a document to the knowledge base.
    Requires WRITE permission.
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    # ADMIN cannot add documents
    if "ADMIN" in user_roles and "USER" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role does not grant access to documents")
    
    kb = get_kb_by_id(kb_id)
    if not kb:
        raise HTTPException(status_code=404, detail="Knowledge base not found")

    permission = get_user_permission_for_kb(
        x_user_id, user_groups, kb["group_name"], kb.get("owner_user_id")
    )
    if permission != "WRITE":
        raise HTTPException(status_code=403, detail="WRITE permission required")

    try:
        from app.knowledge.base import get_knowledge_base
        knowledge = get_knowledge_base()
        
        # Add content with KB ID in metadata
        knowledge.add_content(
            text_content=request.content,
            name=request.name,
            metadata={
                **(request.metadata or {}),
                "knowledge_base_id": kb_id,
                "added_by": x_user_id,
            },
        )
        
        # Update the knowledge_base_id in the embeddings table
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
        
        return {"status": "success", "message": "Document added to knowledge base"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{kb_id}/documents/{doc_id}")
async def delete_document(
    kb_id: str,
    doc_id: str,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Delete a document from the knowledge base.
    Requires WRITE permission.
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    # ADMIN cannot delete documents
    if "ADMIN" in user_roles and "USER" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role does not grant access to documents")
    
    kb = get_kb_by_id(kb_id)
    if not kb:
        raise HTTPException(status_code=404, detail="Knowledge base not found")

    permission = get_user_permission_for_kb(
        x_user_id, user_groups, kb["group_name"], kb.get("owner_user_id")
    )
    if permission != "WRITE":
        raise HTTPException(status_code=403, detail="WRITE permission required")

    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        # Check if document exists and belongs to this KB
        existing = conn.execute(
            text(f"""
                SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings
                WHERE id = :doc_id AND knowledge_base_id = :kb_id
            """),
            {"doc_id": doc_id, "kb_id": kb_id}
        ).fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail="Document not found in this knowledge base")

        conn.execute(
            text(f"DELETE FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings WHERE id = :doc_id"),
            {"doc_id": doc_id}
        )
        conn.commit()
        
        return {"status": "success", "message": "Document deleted"}


@router.post("/{kb_id}/search")
async def search_documents(
    kb_id: str,
    request: SearchRequest,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Search documents in the knowledge base.
    Requires READ permission.
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    # ADMIN cannot search documents
    if "ADMIN" in user_roles and "USER" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role does not grant access to documents")
    
    kb = get_kb_by_id(kb_id)
    if not kb:
        raise HTTPException(status_code=404, detail="Knowledge base not found")

    permission = get_user_permission_for_kb(
        x_user_id, user_groups, kb["group_name"], kb.get("owner_user_id")
    )
    if not permission:
        raise HTTPException(status_code=403, detail="No access to this knowledge base")

    try:
        from app.knowledge.base import get_knowledge_base
        knowledge = get_knowledge_base()

        # Search with KB filter
        results = knowledge.search(query=request.query, max_results=request.limit)
        
        # Filter results to only include docs from this KB
        engine = create_engine(settings.DATABASE_URL)
        with engine.connect() as conn:
            filtered_results = []
            for doc in results:
                # Check if this doc belongs to the requested KB
                check = conn.execute(
                    text(f"""
                        SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings 
                        WHERE content = :content AND knowledge_base_id = :kb_id
                        LIMIT 1
                    """),
                    {"content": doc.content, "kb_id": kb_id}
                ).fetchone()
                
                if check:
                    filtered_results.append({
                        "content": doc.content,
                        "metadata": doc.metadata if hasattr(doc, 'metadata') else {},
                    })
        
        return {
            "status": "success",
            "knowledge_base": kb["name"],
            "results": filtered_results,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{kb_id}/documents")
async def batch_delete_documents(
    kb_id: str,
    request: BatchDeleteRequest,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Delete multiple documents from the knowledge base.
    Requires WRITE permission.
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]

    # ADMIN cannot delete documents
    if "ADMIN" in user_roles and "USER" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role does not grant access to documents")

    kb = get_kb_by_id(kb_id)
    if not kb:
        raise HTTPException(status_code=404, detail="Knowledge base not found")

    permission = get_user_permission_for_kb(
        x_user_id, user_groups, kb["group_name"], kb.get("owner_user_id")
    )
    if permission != "WRITE":
        raise HTTPException(status_code=403, detail="WRITE permission required")

    if not request.document_ids:
        raise HTTPException(status_code=400, detail="No document IDs provided")

    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        # Build placeholders for document IDs
        placeholders = ",".join([f":doc{i}" for i in range(len(request.document_ids))])
        params = {f"doc{i}": doc_id for i, doc_id in enumerate(request.document_ids)}
        params["kb_id"] = kb_id

        # Delete documents that belong to this KB
        result = conn.execute(
            text(f"""
                DELETE FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings
                WHERE id IN ({placeholders}) AND knowledge_base_id = :kb_id
            """),
            params
        )
        conn.commit()

        deleted_count = result.rowcount

        return {
            "status": "success",
            "message": f"{deleted_count} document(s) deleted",
            "deleted_count": deleted_count,
        }
