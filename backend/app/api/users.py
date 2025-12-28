"""
API endpoints for users management (via Keycloak).
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, List
import httpx
import os

router = APIRouter(prefix="/api/users", tags=["users"])

KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM = os.getenv("REALM_NAME", "keystone")
KEYCLOAK_ADMIN = os.getenv("KEYCLOAK_ADMIN", "admin")
KEYCLOAK_ADMIN_PASSWORD = os.getenv("KEYCLOAK_ADMIN_PASSWORD", "admin")


class UserCreate(BaseModel):
    username: str
    email: str
    firstName: str
    lastName: str
    password: str
    roles: Optional[List[str]] = ["USER"]
    groups: Optional[List[str]] = ["/COMPANY"]


class UserUpdate(BaseModel):
    email: Optional[str] = None
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    enabled: Optional[bool] = None


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


@router.get("")
async def list_users(
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """List all users from Keycloak (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users",
                headers={"Authorization": f"Bearer {token}"},
                params={"max": 100},
            )
            
            if response.status_code != 200:
                raise HTTPException(status_code=500, detail="Failed to fetch users from Keycloak")
            
            users = response.json()
            
            # Get groups for each user
            users_with_groups = []
            for u in users:
                groups_resp = await client.get(
                    f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{u['id']}/groups",
                    headers={"Authorization": f"Bearer {token}"},
                )
                groups = [g["path"] for g in groups_resp.json()] if groups_resp.status_code == 200 else []
                
                users_with_groups.append({
                    "id": u["id"],
                    "username": u.get("username"),
                    "email": u.get("email"),
                    "firstName": u.get("firstName"),
                    "lastName": u.get("lastName"),
                    "enabled": u.get("enabled"),
                    "groups": groups,
                })
            
            return {"status": "success", "users": users_with_groups}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.post("")
async def create_user(
    user: UserCreate,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Create a new user in Keycloak (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            # Create user
            response = await client.post(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={
                    "username": user.username,
                    "email": user.email,
                    "firstName": user.firstName,
                    "lastName": user.lastName,
                    "enabled": True,
                    "emailVerified": True,
                    "credentials": [{"type": "password", "value": user.password, "temporary": False}],
                },
            )
            
            if response.status_code == 409:
                raise HTTPException(status_code=409, detail="User already exists")
            
            if response.status_code != 201:
                raise HTTPException(status_code=500, detail=f"Failed to create user: {response.text}")
            
            # Get the created user ID
            location = response.headers.get("Location", "")
            user_id = location.split("/")[-1]
            
            # Assign roles
            for role_name in user.roles or ["USER"]:
                # Get role ID
                role_resp = await client.get(
                    f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/roles/{role_name}",
                    headers={"Authorization": f"Bearer {token}"},
                )
                if role_resp.status_code == 200:
                    role = role_resp.json()
                    await client.post(
                        f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{user_id}/role-mappings/realm",
                        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                        json=[{"id": role["id"], "name": role["name"]}],
                    )
            
            # Assign groups
            for group_path in user.groups or ["/COMPANY"]:
                # Get group ID
                groups_resp = await client.get(
                    f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/groups",
                    headers={"Authorization": f"Bearer {token}"},
                )
                if groups_resp.status_code == 200:
                    for g in groups_resp.json():
                        if g["path"] == group_path:
                            await client.put(
                                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{user_id}/groups/{g['id']}",
                                headers={"Authorization": f"Bearer {token}"},
                            )
                            break
            
            return {"status": "success", "message": f"User '{user.username}' created", "id": user_id}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Delete a user from Keycloak (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{user_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code == 404:
                raise HTTPException(status_code=404, detail="User not found")
            
            if response.status_code != 204:
                raise HTTPException(status_code=500, detail="Failed to delete user")
            
            return {"status": "success", "message": "User deleted"}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.put("/{user_id}/groups/{group_id}")
async def add_user_to_group(
    user_id: str,
    group_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Add a user to a group (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.put(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{user_id}/groups/{group_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code not in [200, 204]:
                raise HTTPException(status_code=500, detail="Failed to add user to group")
            
            return {"status": "success", "message": "User added to group"}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.delete("/{user_id}/groups/{group_id}")
async def remove_user_from_group(
    user_id: str,
    group_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """Remove a user from a group (ADMIN only)."""
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.delete(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{user_id}/groups/{group_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code not in [200, 204]:
                raise HTTPException(status_code=500, detail="Failed to remove user from group")
            
            return {"status": "success", "message": "User removed from group"}
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")
