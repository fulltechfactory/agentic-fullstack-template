"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useSession, signIn } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { CopilotKit } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import { useConversations } from "@/contexts/conversations-context";
import { MessageSquarePlus, Send, Square } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import "@copilotkit/react-ui/styles.css";

// Custom Input component that intercepts messages for title generation
function CustomInput({
  inProgress,
  onSend,
  onStop,
  onMessageIntercepted
}: {
  inProgress: boolean;
  onSend: (text: string) => Promise<unknown>;
  onStop?: () => void;
  onMessageIntercepted?: (message: string) => void;
}) {
  const [value, setValue] = useState("");

  const handleSubmit = async () => {
    if (!value.trim() || inProgress) return;
    const message = value.trim();
    setValue("");

    // Call our interceptor first
    if (onMessageIntercepted) {
      onMessageIntercepted(message);
    }

    // Then send to CopilotKit
    await onSend(message);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  };

  return (
    <div className="flex gap-2 p-4 border-t">
      <Textarea
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder="Type a message..."
        className="min-h-[44px] max-h-[200px] resize-none"
        disabled={inProgress}
      />
      {inProgress ? (
        <Button variant="outline" size="icon" onClick={onStop}>
          <Square className="h-4 w-4" />
        </Button>
      ) : (
        <Button size="icon" onClick={handleSubmit} disabled={!value.trim()}>
          <Send className="h-4 w-4" />
        </Button>
      )}
    </div>
  );
}

// Inner component that handles title generation on first message
function ChatInner({ conversationId, title }: { conversationId: string; title: string }) {
  const { generateTitle } = useConversations();
  const titleGeneratedRef = useRef(false);

  const handleMessageIntercepted = useCallback((message: string) => {
    // Generate title on first message if still default
    if (!titleGeneratedRef.current && title === "New conversation" && message) {
      titleGeneratedRef.current = true;
      generateTitle(conversationId, message);
    }
  }, [conversationId, title, generateTitle]);

  // Create Input component with interceptor
  const InputWithInterceptor = useCallback(
    (props: { inProgress: boolean; onSend: (text: string) => Promise<unknown>; onStop?: () => void }) => (
      <CustomInput {...props} onMessageIntercepted={handleMessageIntercepted} />
    ),
    [handleMessageIntercepted]
  );

  return (
    <CopilotChat
      className="h-full"
      labels={{
        title: title || "AI Assistant",
        initial: "Hello! I can search the knowledge base to help answer your questions. How can I help you today?",
      }}
      Input={InputWithInterceptor}
    />
  );
}

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
      key={currentConversationId}
      runtimeUrl="/api/copilotkit"
      agent="agent"
      threadId={currentConversationId}
    >
      <ChatInner
        conversationId={currentConversationId}
        title={currentConversation?.title || "New conversation"}
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
