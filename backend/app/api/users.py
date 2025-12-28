"""
API endpoints for users management (via Keycloak).
"""

from fastapi import APIRouter, HTTPException, Header
import httpx
from app.config.settings import settings
import os

router = APIRouter(prefix="/api/users", tags=["users"])

KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://keycloak:8080")
KEYCLOAK_REALM = os.getenv("REALM_NAME", "agentic")
KEYCLOAK_ADMIN = os.getenv("KEYCLOAK_ADMIN", "admin")
KEYCLOAK_ADMIN_PASSWORD = os.getenv("KEYCLOAK_ADMIN_PASSWORD", "admin")


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
    """
    List all users from Keycloak (ADMIN only).
    """
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
            
            return {
                "status": "success",
                "users": [
                    {
                        "id": u["id"],
                        "username": u.get("username"),
                        "email": u.get("email"),
                        "firstName": u.get("firstName"),
                        "lastName": u.get("lastName"),
                        "enabled": u.get("enabled"),
                    }
                    for u in users
                ],
            }
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")


@router.get("/{user_id}")
async def get_user(
    user_id: str,
    x_user_roles: str = Header("", alias="X-User-Roles"),
):
    """
    Get a specific user from Keycloak (ADMIN only).
    """
    user_roles = [r.strip() for r in x_user_roles.split(",") if r.strip()]
    
    if "ADMIN" not in user_roles:
        raise HTTPException(status_code=403, detail="ADMIN role required")
    
    try:
        token = await get_admin_token()
        
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{KEYCLOAK_URL}/admin/realms/{KEYCLOAK_REALM}/users/{user_id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            
            if response.status_code == 404:
                raise HTTPException(status_code=404, detail="User not found")
            
            if response.status_code != 200:
                raise HTTPException(status_code=500, detail="Failed to fetch user from Keycloak")
            
            u = response.json()
            
            return {
                "status": "success",
                "user": {
                    "id": u["id"],
                    "username": u.get("username"),
                    "email": u.get("email"),
                    "firstName": u.get("firstName"),
                    "lastName": u.get("lastName"),
                    "enabled": u.get("enabled"),
                },
            }
    except httpx.RequestError as e:
        raise HTTPException(status_code=500, detail=f"Keycloak connection error: {str(e)}")
