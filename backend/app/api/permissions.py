"""
API endpoints for Knowledge Base permissions management.
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy import create_engine, text
from app.config.settings import settings
import uuid

router = APIRouter(prefix="/api/kb", tags=["permissions"])


class PermissionCreate(BaseModel):
    """Request to create a permission."""
    user_id: str
    permission: str  # READ or WRITE


class PermissionResponse(BaseModel):
    """Permission response."""
    id: str
    group_name: str
    user_id: str
    permission: str
    granted_by: Optional[str]
    created_at: Optional[str]


@router.get("/{group_name}/permissions")
async def list_permissions(
    group_name: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    List permissions for a group (ADMIN only).
    """
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    # Normalize group name
    if not group_name.startswith("/"):
        group_name = f"/{group_name}"
    
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT id, group_name, user_id, permission, granted_by, created_at
                FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions
                WHERE group_name = :group_name
                ORDER BY created_at DESC
            """),
            {"group_name": group_name}
        )
        
        permissions = []
        for row in result:
            permissions.append({
                "id": str(row[0]),
                "group_name": row[1],
                "user_id": row[2],
                "permission": row[3],
                "granted_by": row[4],
                "created_at": str(row[5]) if row[5] else None,
            })
        
        return {"status": "success", "permissions": permissions}


@router.post("/{group_name}/permissions")
async def create_permission(
    group_name: str,
    perm: PermissionCreate,
    x_user_id: str = Header(..., alias="X-User-ID"),
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Add a permission for a user on a group (ADMIN only).
    
    - WRITE: User can create KB (if not exists) and manage documents
    - READ: User can read KB even if not member of the group (cross-group access)
    """
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    if perm.permission not in ["READ", "WRITE"]:
        raise HTTPException(status_code=400, detail="Permission must be READ or WRITE")
    
    # Normalize group name
    if not group_name.startswith("/"):
        group_name = f"/{group_name}"
    
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.connect() as conn:
        # Check if permission already exists
        existing = conn.execute(
            text(f"""
                SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions
                WHERE group_name = :group_name 
                  AND user_id = :user_id 
                  AND permission = :permission
            """),
            {"group_name": group_name, "user_id": perm.user_id, "permission": perm.permission}
        ).fetchone()
        
        if existing:
            raise HTTPException(
                status_code=400, 
                detail=f"Permission {perm.permission} already exists for this user on {group_name}"
            )
        
        # Create permission
        perm_id = str(uuid.uuid4())
        conn.execute(
            text(f"""
                INSERT INTO {settings.DB_APP_SCHEMA}.knowledge_base_permissions 
                (id, group_name, user_id, permission, granted_by)
                VALUES (:id, :group_name, :user_id, :permission, :granted_by)
            """),
            {
                "id": perm_id,
                "group_name": group_name,
                "user_id": perm.user_id,
                "permission": perm.permission,
                "granted_by": x_user_id,
            }
        )
        conn.commit()
        
        return {
            "status": "success",
            "message": f"Permission {perm.permission} granted to user on {group_name}",
            "id": perm_id,
        }


@router.delete("/{group_name}/permissions/{perm_id}")
async def delete_permission(
    group_name: str,
    perm_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Remove a permission (ADMIN only).
    """
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    engine = create_engine(settings.DATABASE_URL)
    
    with engine.connect() as conn:
        # Check if permission exists
        existing = conn.execute(
            text(f"SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions WHERE id = :id"),
            {"id": perm_id}
        ).fetchone()
        
        if not existing:
            raise HTTPException(status_code=404, detail="Permission not found")
        
        # Delete permission
        conn.execute(
            text(f"DELETE FROM {settings.DB_APP_SCHEMA}.knowledge_base_permissions WHERE id = :id"),
            {"id": perm_id}
        )
        conn.commit()
        
        return {"status": "success", "message": "Permission removed"}
