"use client";

import { useEffect } from "react";
import { useSession, signIn } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { CopilotKit } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import { useConversations } from "@/contexts/conversations-context";
import { MessageSquarePlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import "@copilotkit/react-ui/styles.css";

function ChatContent() {
  const {
    conversations,
    currentConversationId,
    loading,
    createConversation,
    touchConversation,
  } = useConversations();

  const currentConversation = conversations.find(c => c.id === currentConversationId);

  // Touch conversation when it becomes active (for ordering)
  useEffect(() => {
    if (currentConversationId) {
      touchConversation(currentConversationId);
    }
  }, [currentConversationId, touchConversation]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full text-muted-foreground">
        Loading conversations...
      </div>
    );
  }

  if (!currentConversationId) {
    return (
      <div className="flex flex-col items-center justify-center h-full gap-4">
        <MessageSquarePlus className="h-12 w-12 text-muted-foreground" />
        <p className="text-muted-foreground text-center">
          Select a conversation from the sidebar<br />or start a new one
        </p>
        <Button onClick={() => createConversation()}>
          <MessageSquarePlus className="h-4 w-4 mr-2" />
          New conversation
        </Button>
      </div>
    );
  }

  return (
    <CopilotKit
      runtimeUrl="/api/copilotkit"
      agent="agent"
      threadId={currentConversationId}
    >
      <CopilotChat
        className="h-full"
        labels={{
          title: currentConversation?.title || "AI Assistant",
          initial: "Hello! I can search the knowledge base to help answer your questions. How can I help you today?",
        }}
      />
    </CopilotKit>
  );
}

export default function Home() {
  const { data: session, status } = useSession();

  if (status === "loading") {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center">
        <div className="text-muted-foreground">Loading...</div>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center bg-background">
        <div className="w-full max-w-md text-center">
          <h1 className="text-3xl font-bold mb-8">
            Keystone
          </h1>
          <p className="text-muted-foreground mb-8">
            Please sign in to access the AI assistant.
          </p>
          <button
            onClick={() => signIn("keycloak")}
            className="bg-primary hover:bg-primary/90 text-primary-foreground font-semibold py-3 px-6 rounded-lg transition-colors"
          >
            Sign in with Keycloak
          </button>
        </div>
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
          <h1 className="text-lg font-semibold">Chat</h1>
        </header>
        <main className="flex-1 p-4">
          <div className="h-[calc(100vh-8rem)] rounded-lg border bg-card">
            <ChatContent />
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
