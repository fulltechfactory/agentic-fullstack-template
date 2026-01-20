"use client";

import { useState } from "react";
import { useSession } from "next-auth/react";
import { useRouter } from "next/navigation";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Checkbox } from "@/components/ui/checkbox";
import { useConversations } from "@/contexts/conversations-context";
import {
  MessageSquare,
  Trash2,
  Edit2,
  Check,
  X,
  RefreshCw,
  Plus,
} from "lucide-react";

export default function ConversationsPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const {
    conversations,
    currentConversationId,
    loading,
    setCurrentConversationId,
    createConversation,
    updateConversation,
    deleteConversation,
    deleteConversations,
    refreshConversations,
  } = useConversations();

  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState("");
  const [deleting, setDeleting] = useState(false);

  const toggleSelection = (id: string) => {
    const newSelected = new Set(selectedIds);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedIds(newSelected);
  };

  const toggleSelectAll = () => {
    if (selectedIds.size === conversations.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(conversations.map(c => c.id)));
    }
  };

  const handleStartEdit = (id: string, currentTitle: string) => {
    setEditingId(id);
    setEditTitle(currentTitle);
  };

  const handleSaveEdit = async (id: string) => {
    if (editTitle.trim()) {
      await updateConversation(id, editTitle.trim());
    }
    setEditingId(null);
    setEditTitle("");
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditTitle("");
  };

  const handleDelete = async (id: string) => {
    if (confirm("Delete this conversation?")) {
      await deleteConversation(id);
      selectedIds.delete(id);
      setSelectedIds(new Set(selectedIds));
    }
  };

  const handleDeleteSelected = async () => {
    if (selectedIds.size === 0) return;
    if (!confirm(`Delete ${selectedIds.size} conversation(s)?`)) return;

    setDeleting(true);
    try {
      await deleteConversations(Array.from(selectedIds));
      setSelectedIds(new Set());
    } finally {
      setDeleting(false);
    }
  };

  const handleNewConversation = async () => {
    const conv = await createConversation();
    if (conv) {
      router.push("/");
    }
  };

  const handleSelectConversation = (id: string) => {
    setCurrentConversationId(id);
    router.push("/");
  };

  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return "";
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return "now";
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return date.toLocaleDateString();
  };

  if (status === "loading") {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center">
        <div className="text-muted-foreground">Loading...</div>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center">
        <div className="text-muted-foreground">Please sign in to access this page.</div>
      </main>
    );
  }

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-2 h-4" />
          <h1 className="text-lg font-semibold">All Conversations</h1>
          <div className="ml-auto flex gap-2">
            <Button variant="outline" size="sm" onClick={() => refreshConversations()} disabled={loading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
            <Button size="sm" onClick={handleNewConversation}>
              <Plus className="h-4 w-4 mr-2" />
              New Conversation
            </Button>
          </div>
        </header>
        <main className="flex-1 p-6">
          <div className="max-w-4xl mx-auto">
            {loading ? (
              <div className="flex items-center justify-center h-64 text-muted-foreground">
                Loading conversations...
              </div>
            ) : conversations.length === 0 ? (
              <div className="flex flex-col items-center justify-center h-64 gap-4">
                <MessageSquare className="h-12 w-12 text-muted-foreground" />
                <p className="text-muted-foreground">No conversations yet</p>
                <Button onClick={handleNewConversation}>
                  <Plus className="h-4 w-4 mr-2" />
                  Start a conversation
                </Button>
              </div>
            ) : (
              <div className="space-y-4">
                {/* Batch actions header */}
                <div className="flex items-center justify-between p-3 bg-muted/30 rounded-lg">
                  <div className="flex items-center gap-3">
                    <Checkbox
                      id="select-all"
                      checked={selectedIds.size === conversations.length && conversations.length > 0}
                      onCheckedChange={toggleSelectAll}
                    />
                    <label htmlFor="select-all" className="text-sm cursor-pointer">
                      Select all ({conversations.length})
                    </label>
                  </div>
                  {selectedIds.size > 0 && (
                    <Button
                      size="sm"
                      variant="destructive"
                      onClick={handleDeleteSelected}
                      disabled={deleting}
                    >
                      {deleting ? (
                        <RefreshCw className="h-4 w-4 mr-2 animate-spin" />
                      ) : (
                        <Trash2 className="h-4 w-4 mr-2" />
                      )}
                      Delete {selectedIds.size} selected
                    </Button>
                  )}
                </div>

                {/* Conversations list */}
                <div className="space-y-2">
                  {conversations.map((conv) => (
                    <div
                      key={conv.id}
                      className={`p-4 border rounded-lg bg-card transition-colors ${
                        currentConversationId === conv.id ? "border-primary" : ""
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <Checkbox
                          checked={selectedIds.has(conv.id)}
                          onCheckedChange={() => toggleSelection(conv.id)}
                        />

                        {editingId === conv.id ? (
                          <div className="flex-1 flex items-center gap-2">
                            <Input
                              value={editTitle}
                              onChange={(e) => setEditTitle(e.target.value)}
                              className="flex-1"
                              autoFocus
                              onKeyDown={(e) => {
                                if (e.key === "Enter") handleSaveEdit(conv.id);
                                if (e.key === "Escape") handleCancelEdit();
                              }}
                            />
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={() => handleSaveEdit(conv.id)}
                            >
                              <Check className="h-4 w-4" />
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              onClick={handleCancelEdit}
                            >
                              <X className="h-4 w-4" />
                            </Button>
                          </div>
                        ) : (
                          <>
                            <div
                              className="flex-1 cursor-pointer"
                              onClick={() => handleSelectConversation(conv.id)}
                            >
                              <div className="flex items-center gap-2">
                                <MessageSquare className="h-4 w-4 text-muted-foreground" />
                                <span className="font-medium">{conv.title}</span>
                                {currentConversationId === conv.id && (
                                  <span className="text-xs px-2 py-0.5 rounded bg-primary/10 text-primary">
                                    Current
                                  </span>
                                )}
                              </div>
                              <p className="text-xs text-muted-foreground mt-1">
                                Last active: {formatDate(conv.updated_at)}
                                {conv.created_at && ` • Created: ${new Date(conv.created_at).toLocaleDateString()}`}
                              </p>
                            </div>
                            <div className="flex items-center gap-1">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleStartEdit(conv.id, conv.title)}
                              >
                                <Edit2 className="h-4 w-4" />
                              </Button>
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => handleDelete(conv.id)}
                              >
                                <Trash2 className="h-4 w-4 text-red-500" />
                              </Button>
                            </div>
                          </>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
