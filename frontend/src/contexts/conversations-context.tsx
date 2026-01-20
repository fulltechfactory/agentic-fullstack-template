"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";

interface Conversation {
  id: string;
  user_id: string;
  title: string;
  created_at: string | null;
  updated_at: string | null;
}

interface ConversationsContextType {
  conversations: Conversation[];
  currentConversationId: string | null;
  loading: boolean;
  setCurrentConversationId: (id: string | null) => void;
  createConversation: (title?: string) => Promise<Conversation | null>;
  updateConversation: (id: string, title: string) => Promise<void>;
  deleteConversation: (id: string) => Promise<void>;
  deleteConversations: (ids: string[]) => Promise<void>;
  refreshConversations: () => Promise<void>;
  touchConversation: (id: string) => Promise<void>;
  generateTitle: (id: string, message: string) => Promise<void>;
}

const ConversationsContext = createContext<ConversationsContextType | null>(null);

export function ConversationsProvider({ children }: { children: React.ReactNode }) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [currentConversationId, setCurrentConversationId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshConversations = useCallback(async () => {
    try {
      const res = await fetch("/api/conversations");
      if (res.ok) {
        const data = await res.json();
        setConversations(data.conversations || []);
      }
    } catch (error) {
      console.error("Failed to fetch conversations:", error);
    } finally {
      setLoading(false);
    }
  }, []);

  const createConversation = useCallback(async (title?: string): Promise<Conversation | null> => {
    try {
      const res = await fetch("/api/conversations", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title }),
      });
      if (res.ok) {
        const data = await res.json();
        const newConversation = data.conversation;
        await refreshConversations();
        setCurrentConversationId(newConversation.id);
        return newConversation;
      }
    } catch (error) {
      console.error("Failed to create conversation:", error);
    }
    return null;
  }, [refreshConversations]);

  const updateConversation = useCallback(async (id: string, title: string) => {
    try {
      const res = await fetch(`/api/conversations/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ title }),
      });
      if (res.ok) {
        await refreshConversations();
      }
    } catch (error) {
      console.error("Failed to update conversation:", error);
    }
  }, [refreshConversations]);

  const deleteConversation = useCallback(async (id: string) => {
    try {
      const res = await fetch(`/api/conversations/${id}`, {
        method: "DELETE",
      });
      if (res.ok) {
        if (currentConversationId === id) {
          setCurrentConversationId(null);
        }
        await refreshConversations();
      }
    } catch (error) {
      console.error("Failed to delete conversation:", error);
    }
  }, [currentConversationId, refreshConversations]);

  const deleteConversations = useCallback(async (ids: string[]) => {
    try {
      const res = await fetch("/api/conversations", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ conversation_ids: ids }),
      });
      if (res.ok) {
        if (currentConversationId && ids.includes(currentConversationId)) {
          setCurrentConversationId(null);
        }
        await refreshConversations();
      }
    } catch (error) {
      console.error("Failed to delete conversations:", error);
    }
  }, [currentConversationId, refreshConversations]);

  const touchConversation = useCallback(async (id: string) => {
    try {
      await fetch(`/api/conversations/${id}/touch`, {
        method: "POST",
      });
      // Don't refresh immediately, just update locally for performance
      setConversations(prev => {
        const updated = prev.map(c =>
          c.id === id ? { ...c, updated_at: new Date().toISOString() } : c
        );
        // Re-sort by updated_at
        return updated.sort((a, b) => {
          const aDate = a.updated_at ? new Date(a.updated_at).getTime() : 0;
          const bDate = b.updated_at ? new Date(b.updated_at).getTime() : 0;
          return bDate - aDate;
        });
      });
    } catch (error) {
      console.error("Failed to touch conversation:", error);
    }
  }, []);

  const generateTitle = useCallback(async (id: string, message: string) => {
    try {
      const res = await fetch(`/api/conversations/${id}/generate-title`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message }),
      });
      if (res.ok) {
        const data = await res.json();
        if (data.generated) {
          // Update local state with the new title
          setConversations(prev =>
            prev.map(c =>
              c.id === id ? { ...c, title: data.title } : c
            )
          );
        }
      }
    } catch (error) {
      console.error("Failed to generate title:", error);
    }
  }, []);

  useEffect(() => {
    refreshConversations();
  }, [refreshConversations]);

  return (
    <ConversationsContext.Provider
      value={{
        conversations,
        currentConversationId,
        loading,
        setCurrentConversationId,
        createConversation,
        updateConversation,
        deleteConversation,
        deleteConversations,
        refreshConversations,
        touchConversation,
        generateTitle,
      }}
    >
      {children}
    </ConversationsContext.Provider>
  );
}

export function useConversations() {
  const context = useContext(ConversationsContext);
  if (!context) {
    throw new Error("useConversations must be used within ConversationsProvider");
  }
  return context;
}
