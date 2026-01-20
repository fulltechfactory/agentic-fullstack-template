"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { MessageSquare, Plus, Trash2, Edit2, Check, X, Settings } from "lucide-react";
import Link from "next/link";
import { useConversations } from "@/contexts/conversations-context";
import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarGroupAction,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuAction,
} from "@/components/ui/sidebar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

export function NavConversations() {
  const router = useRouter();
  const {
    conversations,
    currentConversationId,
    loading,
    setCurrentConversationId,
    createConversation,
    updateConversation,
    deleteConversation,
  } = useConversations();

  const [editingId, setEditingId] = useState<string | null>(null);
  const [editTitle, setEditTitle] = useState("");

  const handleNewConversation = async () => {
    await createConversation();
    router.push("/");
  };

  const handleSelectConversation = (id: string) => {
    setCurrentConversationId(id);
    router.push("/");
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
    }
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
    if (diffMins < 60) return `${diffMins}m`;
    if (diffHours < 24) return `${diffHours}h`;
    if (diffDays < 7) return `${diffDays}d`;
    return date.toLocaleDateString();
  };

  return (
    <SidebarGroup>
      <SidebarGroupLabel>
        Conversations
        <SidebarGroupAction onClick={handleNewConversation} title="New conversation">
          <Plus className="h-4 w-4" />
        </SidebarGroupAction>
      </SidebarGroupLabel>
      <SidebarMenu>
        {loading ? (
          <SidebarMenuItem>
            <SidebarMenuButton disabled>
              <span className="text-muted-foreground text-sm">Loading...</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        ) : conversations.length === 0 ? (
          <SidebarMenuItem>
            <SidebarMenuButton onClick={handleNewConversation}>
              <Plus className="h-4 w-4" />
              <span>Start a conversation</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        ) : (
          <>
            {conversations.slice(0, 10).map((conv) => (
              <SidebarMenuItem key={conv.id}>
                {editingId === conv.id ? (
                  <div className="flex items-center gap-1 px-2 py-1 w-full">
                    <Input
                      value={editTitle}
                      onChange={(e) => setEditTitle(e.target.value)}
                      className="h-7 text-sm"
                      autoFocus
                      onKeyDown={(e) => {
                        if (e.key === "Enter") handleSaveEdit(conv.id);
                        if (e.key === "Escape") handleCancelEdit();
                      }}
                    />
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7 w-7 p-0"
                      onClick={() => handleSaveEdit(conv.id)}
                    >
                      <Check className="h-3 w-3" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-7 w-7 p-0"
                      onClick={handleCancelEdit}
                    >
                      <X className="h-3 w-3" />
                    </Button>
                  </div>
                ) : (
                  <>
                    <SidebarMenuButton
                      isActive={currentConversationId === conv.id}
                      onClick={() => handleSelectConversation(conv.id)}
                      tooltip={conv.title}
                    >
                      <MessageSquare className="h-4 w-4" />
                      <span className="truncate flex-1">{conv.title}</span>
                      <span className="text-xs text-muted-foreground">
                        {formatDate(conv.updated_at)}
                      </span>
                    </SidebarMenuButton>
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <SidebarMenuAction>
                          <Settings className="h-4 w-4" />
                        </SidebarMenuAction>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent side="right" align="start">
                        <DropdownMenuItem onClick={() => handleStartEdit(conv.id, conv.title)}>
                          <Edit2 className="h-4 w-4 mr-2" />
                          Rename
                        </DropdownMenuItem>
                        <DropdownMenuItem
                          onClick={() => handleDelete(conv.id)}
                          className="text-red-600"
                        >
                          <Trash2 className="h-4 w-4 mr-2" />
                          Delete
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </>
                )}
              </SidebarMenuItem>
            ))}
            {conversations.length > 10 && (
              <SidebarMenuItem>
                <SidebarMenuButton asChild>
                  <Link href="/conversations">
                    <span className="text-muted-foreground">
                      View all ({conversations.length})
                    </span>
                  </Link>
                </SidebarMenuButton>
              </SidebarMenuItem>
            )}
          </>
        )}
      </SidebarMenu>
    </SidebarGroup>
  );
}
