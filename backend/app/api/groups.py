"""
API endpoints for groups management (via Keycloak).
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
import httpx
import os
from sqlalchemy import create_engine, text
from app.config.settings import settings

router = APIRouter(prefix="/api/groups", tags=["groups"])

KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM = os.getenv("REALM_NAME", "keystone")
KEYCLOAK_ADMIN = os.getenv("KEYCLOAK_ADMIN", "admin")
KEYCLOAK_ADMIN_PASSWORD = os.getenv("KEYCLOAK_ADMIN_PASSWORD", "admin")


class GroupCreate(BaseModel):
    name: str  # e.g., "RH", "FINANCE"


async def get_admin_token() -> str:
    """Get admin access token from Keycloak."""
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{KEYCLOAK_URL}/realms/master/protocol/openid-connect/token",
            data={
                "grant_type": "password",
                "client_id": "admin-cli",
                "username": KEYCLOAK_ADMIN,
                "password": KEYCLOAK_ADMIN_PASSWORD,
            },
        )
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to authenticate with Keycloak")
        return response.json()["access_token"]


def create_knowledge_base_for_group(group_name: str, group_path: str):
    """Create a knowledge base for a new group."""
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        # Check if KB already exists
        result = conn.execute(
            text(f"SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_bases WHERE group_name = :group_path"),
            {"group_path": group_path}
        ).fetchone()
        
        if not result:
            conn.execute(
                text(f"""
                    INSERT INTO {settings.DB_APP_SCHEMA}.knowledge_bases 
                    (name, slug, description, group_name, created_by, is_active)
                    VALUES (:name, :slug, :description, :group_path, 'system', true)
                """),
                {
                    "name": group_name,
                    "slug": group_name.lower().replace(" ", "_"),
                    "description": f"Knowledge base for {group_name} group",
                    "group_path": group_path,
                }
            )
            conn.commit()


def delete_knowledge_base_for_group(group_path: str):
    """Delete the knowledge base associated with a group."""
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        conn.execute(
            text(f"DELETE FROM {settings.DB_APP_SCHEMA}.knowledge_bases WHERE group_name = :group_path"),
            {"group_path": group_path}
        )
        conn.commit()


@router.get("")
async def list_groups(
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """List all groups from Keycloak (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code != 200:
                raise HTTPException(status_code=500, detail="Failed to fetch groups from Keycloak")
            
            groups = response.json()
            
            # Get member count for each group
            groups_with_count = []
            for g in groups:
                members_resp = await client.get(
                    f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups/{g['id']}/members",
                    headers={"Authorization": f"Bearer {token}"},
                )
                member_count = len(members_resp.json()) if members_resp.status_code == 200 else 0
                
                groups_with_count.append({
                    "id": g["id"],
                    "name": g["name"],
                    "path": g["path"],
                    "memberCount": member_count,
                })
            
            return {"status": "success", "groups": groups_with_count}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.post("")
async def create_group(
    group: GroupCreate,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Create a new group in Keycloak and its associated KB (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    # Normalize group name (uppercase, no spaces)
    group_name = group.name.upper().replace(" ", "_")
    group_path = f"/{group_name}"
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"name": group_name},
            )
            
            if response.status_code == 409:
                raise HTTPException(status_code=409, detail="Group already exists")
            
            if response.status_code != 201:
                raise HTTPException(status_code=500, detail=f"Failed to create group: {response.text}")
            
            # Get the created group ID
            location = response.headers.get("Location", "")
            group_id = location.split("/")[-1]
            
            # Create associated knowledge base
            create_knowledge_base_for_group(group_name, group_path)
            
            return {
                "status": "success", 
                "message": f"Group '{group_name}' created with associated Knowledge Base", 
                "id": group_id,
                "path": group_path,
            }
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.delete("/{group_id}")
async def delete_group(
    group_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Delete a group from Keycloak and its associated KB (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            # Check if it's COMPANY group (protected)
            group_resp = await client.get(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups/{group_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if group_resp.status_code == 200:
                group = group_resp.json()
                if group.get("name") == "COMPANY":
                    raise HTTPException(status_code=400, detail="Cannot delete COMPANY group")
                
                group_path = group.get("path", "")
            else:
                group_path = ""
            
            response = await client.delete(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups/{group_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code == 404:
                raise HTTPException(status_code=404, detail="Group not found")
            
            if response.status_code != 204:
                raise HTTPException(status_code=500, detail="Failed to delete group")
            
            # Delete associated knowledge base
            if group_path:
                delete_knowledge_base_for_group(group_path)
            
            return {"status": "success", "message": "Group and associated Knowledge Base deleted"}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.get("/{group_id}/members")
async def get_group_members(
    group_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Get members of a group (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups/{group_id}/members",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code == 404:
                raise HTTPException(status_code=404, detail="Group not found")
            
            if response.status_code != 200:
                raise HTTPException(status_code=500, detail="Failed to fetch group members")
            
            members = response.json()
            
            return {
                "status": "success",
                "members": [
                    {
                        "id": m["id"],
                        "username": m.get("username"),
                        "email": m.get("email"),
                        "firstName": m.get("firstName"),
                        "lastName": m.get("lastName"),
                    }
                    for m in members
                ],
            }
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")
