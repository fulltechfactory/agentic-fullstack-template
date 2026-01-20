"""
API endpoints for conversations management.
"""

from fastapi import APIRouter, HTTPException, Header
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy import create_engine, text
from app.config.settings import settings
from app.config.models import get_model
import uuid
import asyncio

router = APIRouter(prefix="/api/conversations", tags=["conversations"])


class ConversationCreate(BaseModel):
    """Request to create a conversation."""
    title: Optional[str] = None


class ConversationUpdate(BaseModel):
    """Request to update a conversation."""
    title: str


class ConversationResponse(BaseModel):
    """Conversation response."""
    id: str
    user_id: str
    title: str
    created_at: Optional[str]
    updated_at: Optional[str]


class BatchDeleteRequest(BaseModel):
    """Request to delete multiple conversations."""
    conversation_ids: List[str]


class GenerateTitleRequest(BaseModel):
    """Request to generate a title from a message."""
    message: str


@router.get("")
async def list_conversations(
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    List all conversations for the current user.
    Ordered by most recently updated first.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT id, user_id, title, created_at, updated_at
                FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE user_id = :user_id
                ORDER BY updated_at DESC
            """),
            {"user_id": x_user_id}
        )

        conversations = []
        for row in result:
            conversations.append({
                "id": str(row[0]),
                "user_id": row[1],
                "title": row[2],
                "created_at": str(row[3]) if row[3] else None,
                "updated_at": str(row[4]) if row[4] else None,
            })

        return {"status": "success", "conversations": conversations}


@router.post("")
async def create_conversation(
    request: ConversationCreate,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Create a new conversation.
    """
    engine = create_engine(settings.DATABASE_URL)
    conversation_id = str(uuid.uuid4())
    title = request.title or "New conversation"

    with engine.connect() as conn:
        conn.execute(
            text(f"""
                INSERT INTO {settings.DB_APP_SCHEMA}.conversations
                (id, user_id, title)
                VALUES (:id, :user_id, :title)
            """),
            {
                "id": conversation_id,
                "user_id": x_user_id,
                "title": title,
            }
        )
        conn.commit()

        return {
            "status": "success",
            "conversation": {
                "id": conversation_id,
                "user_id": x_user_id,
                "title": title,
            }
        }


@router.get("/{conversation_id}")
async def get_conversation(
    conversation_id: str,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Get a specific conversation.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                SELECT id, user_id, title, created_at, updated_at
                FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id = :id AND user_id = :user_id
            """),
            {"id": conversation_id, "user_id": x_user_id}
        ).fetchone()

        if not result:
            raise HTTPException(status_code=404, detail="Conversation not found")

        return {
            "status": "success",
            "conversation": {
                "id": str(result[0]),
                "user_id": result[1],
                "title": result[2],
                "created_at": str(result[3]) if result[3] else None,
                "updated_at": str(result[4]) if result[4] else None,
            }
        }


@router.put("/{conversation_id}")
async def update_conversation(
    conversation_id: str,
    request: ConversationUpdate,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Update a conversation (rename).
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        # Check ownership
        existing = conn.execute(
            text(f"""
                SELECT id FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id = :id AND user_id = :user_id
            """),
            {"id": conversation_id, "user_id": x_user_id}
        ).fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail="Conversation not found")

        conn.execute(
            text(f"""
                UPDATE {settings.DB_APP_SCHEMA}.conversations
                SET title = :title, updated_at = NOW()
                WHERE id = :id
            """),
            {"id": conversation_id, "title": request.title}
        )
        conn.commit()

        return {"status": "success", "message": "Conversation updated"}


@router.delete("/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Delete a conversation and its associated Agno session.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        # Check ownership
        existing = conn.execute(
            text(f"""
                SELECT id FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id = :id AND user_id = :user_id
            """),
            {"id": conversation_id, "user_id": x_user_id}
        ).fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail="Conversation not found")

        # Delete Agno session (conversation_id is used as session_id)
        conn.execute(
            text(f"""
                DELETE FROM {settings.DB_APP_SCHEMA}.agent_sessions
                WHERE session_id = :session_id
            """),
            {"session_id": conversation_id}
        )

        # Delete conversation
        conn.execute(
            text(f"""
                DELETE FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id = :id
            """),
            {"id": conversation_id}
        )
        conn.commit()

        return {"status": "success", "message": "Conversation deleted"}


@router.delete("")
async def batch_delete_conversations(
    request: BatchDeleteRequest,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Delete multiple conversations.
    """
    if not request.conversation_ids:
        raise HTTPException(status_code=400, detail="No conversation IDs provided")

    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        # Build placeholders
        placeholders = ",".join([f":id{i}" for i in range(len(request.conversation_ids))])
        params = {f"id{i}": cid for i, cid in enumerate(request.conversation_ids)}
        params["user_id"] = x_user_id

        # Get conversations that belong to user
        result = conn.execute(
            text(f"""
                SELECT id FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id IN ({placeholders}) AND user_id = :user_id
            """),
            params
        )
        valid_ids = [str(row[0]) for row in result]

        if not valid_ids:
            raise HTTPException(status_code=404, detail="No valid conversations found")

        # Delete Agno sessions
        session_placeholders = ",".join([f":sid{i}" for i in range(len(valid_ids))])
        session_params = {f"sid{i}": sid for i, sid in enumerate(valid_ids)}

        conn.execute(
            text(f"""
                DELETE FROM {settings.DB_APP_SCHEMA}.agent_sessions
                WHERE session_id IN ({session_placeholders})
            """),
            session_params
        )

        # Delete conversations
        conv_placeholders = ",".join([f":cid{i}" for i in range(len(valid_ids))])
        conv_params = {f"cid{i}": cid for i, cid in enumerate(valid_ids)}

        result = conn.execute(
            text(f"""
                DELETE FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id IN ({conv_placeholders})
            """),
            conv_params
        )
        conn.commit()

        deleted_count = result.rowcount

        return {
            "status": "success",
            "message": f"{deleted_count} conversation(s) deleted",
            "deleted_count": deleted_count,
        }


@router.post("/{conversation_id}/touch")
async def touch_conversation(
    conversation_id: str,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Update the updated_at timestamp of a conversation.
    Called when a new message is sent.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        result = conn.execute(
            text(f"""
                UPDATE {settings.DB_APP_SCHEMA}.conversations
                SET updated_at = NOW()
                WHERE id = :id AND user_id = :user_id
            """),
            {"id": conversation_id, "user_id": x_user_id}
        )
        conn.commit()

        if result.rowcount == 0:
            raise HTTPException(status_code=404, detail="Conversation not found")

        return {"status": "success"}


@router.get("/{conversation_id}/history")
async def get_conversation_history(
    conversation_id: str,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Get the message history for a conversation.
    Extracts messages from Agno agent_sessions.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        # Verify conversation ownership
        existing = conn.execute(
            text(f"""
                SELECT id FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id = :id AND user_id = :user_id
            """),
            {"id": conversation_id, "user_id": x_user_id}
        ).fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail="Conversation not found")

        # Get session data from Agno
        session = conn.execute(
            text(f"""
                SELECT runs FROM {settings.DB_APP_SCHEMA}.agent_sessions
                WHERE session_id = :session_id
            """),
            {"session_id": conversation_id}
        ).fetchone()

        if not session or not session[0]:
            return {"status": "success", "messages": []}

        # Extract messages from all runs
        messages = []
        runs = session[0]

        for run in runs:
            run_messages = run.get("messages", [])
            for msg in run_messages:
                role = msg.get("role")
                content = msg.get("content", "")

                # Only include user and assistant messages
                if role in ("user", "assistant") and content:
                    messages.append({
                        "id": msg.get("id"),
                        "role": role,
                        "content": content,
                        "created_at": msg.get("created_at"),
                    })

        return {"status": "success", "messages": messages}


@router.post("/{conversation_id}/generate-title")
async def generate_title(
    conversation_id: str,
    request: GenerateTitleRequest,
    x_user_id: str = Header(..., alias="X-User-ID"),
):
    """
    Generate a title for the conversation based on the first message.
    Uses the AI model to create a short, relevant title.
    """
    engine = create_engine(settings.DATABASE_URL)

    with engine.connect() as conn:
        # Check ownership and current title
        existing = conn.execute(
            text(f"""
                SELECT id, title FROM {settings.DB_APP_SCHEMA}.conversations
                WHERE id = :id AND user_id = :user_id
            """),
            {"id": conversation_id, "user_id": x_user_id}
        ).fetchone()

        if not existing:
            raise HTTPException(status_code=404, detail="Conversation not found")

        # Only generate if title is still default
        current_title = existing[1]
        if current_title != "New conversation":
            return {"status": "success", "title": current_title, "generated": False}

        # Generate title using AI
        try:
            model = get_model()
            prompt = f"""Generate a very short title (3-5 words maximum) for a conversation that starts with this message.
Return ONLY the title, nothing else. No quotes, no punctuation at the end.

User message: {request.message[:500]}"""

            # Run sync model in thread pool
            response = await asyncio.to_thread(
                model.invoke,
                prompt
            )

            # Extract the generated title
            generated_title = response.content.strip().strip('"\'')[:100]

            # Update the conversation title
            conn.execute(
                text(f"""
                    UPDATE {settings.DB_APP_SCHEMA}.conversations
                    SET title = :title, updated_at = NOW()
                    WHERE id = :id
                """),
                {"id": conversation_id, "title": generated_title}
            )
            conn.commit()

            return {"status": "success", "title": generated_title, "generated": True}

        except Exception as e:
            # If AI fails, use truncated message as fallback
            fallback_title = request.message[:50].strip()
            if len(request.message) > 50:
                fallback_title += "..."

            conn.execute(
                text(f"""
                    UPDATE {settings.DB_APP_SCHEMA}.conversations
                    SET title = :title, updated_at = NOW()
                    WHERE id = :id
                """),
                {"id": conversation_id, "title": fallback_title}
            )
            conn.commit()

            return {"status": "success", "title": fallback_title, "generated": True, "fallback": True}
