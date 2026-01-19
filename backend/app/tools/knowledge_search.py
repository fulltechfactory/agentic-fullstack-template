"""
Knowledge search tool with group-based filtering.
Uses contextvars to get user context per request.
"""
from typing import List, Optional
from contextvars import ContextVar
from sqlalchemy import create_engine, text
from app.config.settings import settings

# Context variables for user info (set per request)
current_user_id: ContextVar[str] = ContextVar('current_user_id', default='')
current_user_groups: ContextVar[List[str]] = ContextVar('current_user_groups', default=[])


def set_user_context(user_id: str, user_groups: List[str]):
    """Set user context for current request."""
    current_user_id.set(user_id)
    current_user_groups.set(user_groups)


def get_accessible_kb_ids(user_id: str, user_groups: List[str]) -> List[str]:
    """
    Get list of KB IDs the user can access.
    """
    accessible_kb_ids = []
    
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as conn:
        # Get KBs for user's groups
        if user_groups:
            placeholders = ",".join([f":g{i}" for i in range(len(user_groups))])
            params = {f"g{i}": g for i, g in enumerate(user_groups)}
            
            result = conn.execute(
                text(f"""
                    SELECT id FROM {settings.DB_APP_SCHEMA}.knowledge_bases
                    WHERE group_name IN ({placeholders}) AND is_active = true
                """),
                params
            )
            for row in result:
                accessible_kb_ids.append(str(row[0]))
        
        # Get KBs from explicit permissions
        result = conn.execute(
            text(f"""
                SELECT DISTINCT kb.id 
                FROM {settings.DB_APP_SCHEMA}.knowledge_bases kb
                JOIN {settings.DB_APP_SCHEMA}.knowledge_base_permissions p
                    ON kb.group_name = p.group_name
                WHERE p.user_id = :user_id AND kb.is_active = true
            """),
            {"user_id": user_id}
        )
        for row in result:
            kb_id = str(row[0])
            if kb_id not in accessible_kb_ids:
                accessible_kb_ids.append(kb_id)
    
    return accessible_kb_ids


def search_knowledge_base(query: str) -> str:
    """
    Search the knowledge base for information relevant to the query.
    Use this tool when the user asks about company documents, policies, or information.

    Args:
        query: The search query describing what information to find

    Returns:
        Relevant documents from the knowledge base with source citations
    """
    user_id = current_user_id.get()
    user_groups = current_user_groups.get()

    if not user_id:
        return "User context not available. Cannot search knowledge base."

    accessible_kb_ids = get_accessible_kb_ids(user_id, user_groups)

    if not accessible_kb_ids:
        return "You don't have access to any knowledge base."
    
    try:
        from app.knowledge.base import get_knowledge_base
        knowledge = get_knowledge_base()
        
        # Search all documents
        all_results = knowledge.search(query=query, max_results=15)
        
        if not all_results:
            return "No relevant information found in the knowledge base."
        
        # Filter by accessible KBs
        engine = create_engine(settings.DATABASE_URL)
        filtered_results = []

        with engine.connect() as conn:
            placeholders = ",".join([f":kb{i}" for i in range(len(accessible_kb_ids))])
            kb_params = {f"kb{i}": kb_id for i, kb_id in enumerate(accessible_kb_ids)}

            for doc in all_results:
                if len(filtered_results) >= 5:
                    break

                # Check if document belongs to accessible KB
                result = conn.execute(
                    text(f"""
                        SELECT ke.id, ke.name, kb.name as kb_name, kb.group_name
                        FROM {settings.DB_APP_SCHEMA}.knowledge_embeddings ke
                        JOIN {settings.DB_APP_SCHEMA}.knowledge_bases kb
                            ON ke.knowledge_base_id = kb.id
                        WHERE ke.content = :content
                          AND ke.knowledge_base_id IN ({placeholders})
                        LIMIT 1
                    """),
                    {"content": doc.content, **kb_params}
                ).fetchone()

                if result:
                    filtered_results.append({
                        "content": doc.content,
                        "name": result[1] or "Document",
                        "kb_name": result[2],
                        "group_name": result[3],
                    })
        
        if not filtered_results:
            return "No relevant information found in the knowledge bases you have access to."
        
        # Format results with sources
        formatted = []
        for doc in filtered_results:
            source = f"[Source: {doc['name']} - {doc['kb_name']}]"
            formatted.append(f"{source}\n{doc['content']}")
        
        return "\n\n---\n\n".join(formatted)
        
    except Exception as e:
        print(f"[ERROR] Knowledge search failed: {e}")
        return f"Error searching knowledge base: {str(e)}"
