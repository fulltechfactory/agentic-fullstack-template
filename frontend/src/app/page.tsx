"use client";

import { useSession, signIn } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { CopilotKit } from "@copilotkit/react-core";
import { CopilotChat } from "@copilotkit/react-ui";
import "@copilotkit/react-ui/styles.css";

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
            Agentic App
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

  // Use Keycloak user ID as thread ID for session persistence
  const threadId = session.user?.id || "default";

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
            <CopilotKit runtimeUrl="/api/copilotkit" agent="agent" threadId={threadId}>
              <CopilotChat
                className="h-full"
                labels={{
                  title: "AI Assistant",
                  initial: "Hello! How can I help you today?",
                }}
              />
            </CopilotKit>
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
