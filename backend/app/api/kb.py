"""
API endpoints for Knowledge Bases management.
Supports both group-based KBs and personal KBs.
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy import create_engine, text
from app.config.settings import settings
import uuid

router = APIRouter(prefix="/api/kb", tags=["knowledge-bases"])


class KnowledgeBaseCreate(BaseModel):
    """Request to create a knowledge base."""
    name: str
    slug: str
    description: Optional[str] = None
    group_name: str  # e.g., "/RH"


class KnowledgeBaseResponse(BaseModel):
    """Knowledge base response."""
    id: str
    name: str
    slug: str
    description: Optional[str]
    group_name: Optional[str]
    owner_user_id: Optional[str] = None
    is_personal: bool = False
    created_by: Optional[str]
    created_at: Optional[str]
    is_active: bool
    document_count: int = 0
    permission: str = "READ"  # User's permission level


def get_or_create_personal_kb(user_id: str) -> dict:
    """
    Get or create a personal knowledge base for a user.
    Returns the KB info dict.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        # Check if personal KB exists
        result = conn.execute(
            text(f"""
                SELECT id, name, slug, description, created_at, is_active
                FROM {settings.DB_APP_SCHEMA}.knowledge_bases
                WHERE owner_user_id = :user_id
            """),
            {"user_id": user_id}
        ).fetchone()

        if result:
            # Get document count
            doc_count = conn.execute(
                text(f"""
                    SELECT COUNT(*) FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings
                    WHERE knowledge_base_id = :kb_id
                """),
                {"kb_id": str(result[0])}
            ).scalar() or 0

            return {
                "id": str(result[0]),
                "name": result[1],
                "slug": result[2],
                "description": result[3],
                "group_name": None,
                "owner_user_id": user_id,
                "is_personal": True,
                "created_by": user_id,
                "created_at": str(result[4]) if result[4] else None,
                "is_active": result[5],
                "document_count": doc_count,
                "permission": "WRITE",
            }

        # Create personal KB
        kb_id = str(uuid.uuid4())
        slug = f"personal-{user_id[:8]}"

        conn.execute(
            text(f"""
                INSERT INTO {settings.DB_APP_SCHEMA}.knowledge_bases
                (id, name, slug, description, owner_user_id, created_by)
                VALUES (:id, :name, :slug, :description, :owner_user_id, :created_by)
            """),
            {
                "id": kb_id,
                "name": "My Personal KB",
                "slug": slug,
                "description": "Personal knowledge base",
                "owner_user_id": user_id,
                "created_by": user_id,
            }
        )
        conn.commit()

        return {
            "id": kb_id,
            "name": "My Personal KB",
            "slug": slug,
            "description": "Personal knowledge base",
            "group_name": None,
            "owner_user_id": user_id,
            "is_personal": True,
            "created_by": user_id,
            "created_at": None,
            "is_active": True,
            "document_count": 0,
            "permission": "WRITE",
        }


def get_user_permissions(user_id: str, user_groups: List[str]) -> dict:
    """
    Get user's permissions for all KBs.
    Returns dict: {group_name: permission_level}
    
    Rules:
    - Member of group = READ (implicit)
    - Explicit WRITE permission in DB = WRITE
    - Explicit READ permission in DB = READ (for cross-group access)
    """
    permissions = {}
    
    # Implicit READ for all groups user belongs to
    for group in user_groups:
        permissions[group] = "READ"
    
    # Check explicit permissions in DB
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT group_name, permission 
                FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions
                WHERE user_id = :user_id
            """),
            {"user_id": user_id}
        )
        for row in result:
            group_name = row[0]
            permission = row[1]
            # WRITE overrides READ
            if permission == "WRITE" or group_name not in permissions:
                permissions[group_name] = permission
    
    return permissions


@router.get("/personal")
async def get_personal_knowledge_base(
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Get or create the user's personal knowledge base.
    Auto-creates a personal KB if it doesn't exist.
    """
    personal_kb = get_or_create_personal_kb(x_user_id)
    return {"status": "success", "knowledge_base": personal_kb}


@router.get("")
async def list_knowledge_bases(
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    List knowledge bases accessible to the user.

    - Regular users: see personal KB + KBs for their groups + explicit permissions
    - Admin users: see all KBs (for management) but no data access
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    is_admin = "ADMIN" in user_roles

    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        if is_admin:
            # Admin sees all KBs (for management purposes)
            result = conn.execute(
                text(f"""
                    SELECT kb.id, kb.name, kb.slug, kb.description, kb.group_name,
                           kb.owner_user_id, kb.created_by, kb.created_at, kb.is_active,
                           COUNT(ke.id) as doc_count
                    FROM {settings.DB_APP_SCHEMA}.knowledge_bases kb
                    LEFT JOIN {settings.DB_APP_SCHEMA}.knowledge_embeddings ke
                        ON ke.knowledge_base_id = kb.id
                    GROUP BY kb.id
                    ORDER BY kb.owner_user_id NULLS LAST, kb.name
                """)
            )
            kbs = []
            for row in result:
                kbs.append({
                    "id": str(row[0]),
                    "name": row[1],
                    "slug": row[2],
                    "description": row[3],
                    "group_name": row[4],
                    "owner_user_id": row[5],
                    "is_personal": row[5] is not None,
                    "created_by": row[6],
                    "created_at": str(row[7]) if row[7] else None,
                    "is_active": row[8],
                    "document_count": row[9],
                    "permission": "ADMIN",  # Admin can manage but not access data
                })
            return {"status": "success", "knowledge_bases": kbs}

        # Regular user: start with personal KB
        kbs = []
        personal_kb = get_or_create_personal_kb(x_user_id)
        kbs.append(personal_kb)

        # Get permissions for group KBs
        permissions = get_user_permissions(x_user_id, user_groups)

        if permissions:
            # Get KBs for groups user has access to
            group_list = list(permissions.keys())
            placeholders = ",".join([f":g{i}" for i in range(len(group_list))])
            params = {f"g{i}": g for i, g in enumerate(group_list)}

            result = conn.execute(
                text(f"""
                    SELECT kb.id, kb.name, kb.slug, kb.description, kb.group_name,
                           kb.created_by, kb.created_at, kb.is_active,
                           COUNT(ke.id) as doc_count
                    FROM {settings.DB_APP_SCHEMA}.knowledge_bases kb
                    LEFT JOIN {settings.DB_APP_SCHEMA}.knowledge_embeddings ke
                        ON ke.knowledge_base_id = kb.id
                    WHERE kb.group_name IN ({placeholders})
                      AND kb.is_active = true
                    GROUP BY kb.id
                    ORDER BY kb.name
                """),
                params
            )

            for row in result:
                group_name = row[4]
                kbs.append({
                    "id": str(row[0]),
                    "name": row[1],
                    "slug": row[2],
                    "description": row[3],
                    "group_name": group_name,
                    "owner_user_id": None,
                    "is_personal": False,
                    "created_by": row[5],
                    "created_at": str(row[6]) if row[6] else None,
                    "is_active": row[7],
                    "document_count": row[8],
                    "permission": permissions.get(group_name, "READ"),
                })

        return {"status": "success", "knowledge_bases": kbs}


@router.post("")
async def create_knowledge_base(
    kb: KnowledgeBaseCreate,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_groups: str = Header(..., alias="X-User-Groups"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Create a new knowledge base.
    
    - Requires WRITE permission on the group
    - Or ADMIN role
    """
    user_groups = [g.strip() for g in x_user_groups.split(",") if g.strip()]
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    is_admin = "ADMIN" in user_roles
    
    # Check permission
    if not is_admin:
        permissions = get_user_permissions(x_user_id, user_groups)
        if permissions.get(kb.group_name) != "WRITE":
            raise HTTPException(
                status_code=403, 
                detail=f"WRITE permission required on group {kb.group_name}"
            )
    
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.connect() as conn:
        # Check if slug already exists
        existing = conn.execute(
            text(f"SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_bases WHERE slug = :slug"),
            {"slug": kb.slug}
        ).fetchone()
        
        if existing:
            raise HTTPException(status_code=400, detail=f"Slug '{kb.slug}' already exists")
        
        # Check if KB already exists for this group
        existing_group = conn.execute(
            text(f"SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_bases WHERE group_name = :group_name"),
            {"group_name": kb.group_name}
        ).fetchone()
        
        if existing_group:
            raise HTTPException(
                status_code=400, 
                detail=f"Knowledge base already exists for group {kb.group_name}"
            )
        
        # Create KB
        kb_id = str(uuid.uuid4())
        conn.execute(
            text(f"""
                INSERT INTO {settings.DB_APP_SCHEMA}.knowledge_bases 
                (id, name, slug, description, group_name, created_by)
                VALUES (:id, :name, :slug, :description, :group_name, :created_by)
            """),
            {
                "id": kb_id,
                "name": kb.name,
                "slug": kb.slug,
                "description": kb.description,
                "group_name": kb.group_name,
                "created_by": x_user_id,
            }
        )
        conn.commit()
        
        return {
            "status": "success",
            "message": f"Knowledge base '{kb.name}' created",
            "id": kb_id,
        }


@router.delete("/{kb_id}")
async def delete_knowledge_base(
    kb_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Delete a knowledge base (ADMIN only).
    """
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.connect() as conn:
        # Check if KB exists
        existing = conn.execute(
            text(f"SELECT slug FROM {settings.DB_APP_SCHEMA}.knowledge_bases WHERE id = :id"),
            {"id": kb_id}
        ).fetchone()
        
        if not existing:
            raise HTTPException(status_code=404, detail="Knowledge base not found")
        
        if existing[0] == "company":
            raise HTTPException(status_code=400, detail="Cannot delete the Company knowledge base")
        
        # Delete KB (CASCADE will delete embeddings)
        conn.execute(
            text(f"DELETE FROM {settings.DB_APP_SCHEMA}.knowledge_bases WHERE id = :id"),
            {"id": kb_id}
        )
        conn.commit()
        
        return {"status": "success", "message": "Knowledge base deleted"}
