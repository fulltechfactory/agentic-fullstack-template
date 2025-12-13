"use client";

import { CopilotChat } from "@copilotkit/react-ui";
import "@copilotkit/react-ui/styles.css";
import { useSession, signIn, signOut } from "next-auth/react";

export default function Home() {
  const { data: session, status } = useSession();

  if (status === "loading") {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-gray-50">
        <div className="text-gray-600">Loading...</div>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-gray-50">
        <div className="w-full max-w-md text-center">
          <h1 className="text-3xl font-bold mb-8 text-gray-800">
            Agentic Fullstack Template
          </h1>
          <p className="text-gray-600 mb-8">
            Please sign in to access the AI assistant.
          </p>
          <button
            onClick={() => signIn("keycloak")}
            className="bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 px-6 rounded-lg transition-colors"
          >
            Sign in with Keycloak
          </button>
        </div>
      </main>
    );
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-gray-50">
      <div className="w-full max-w-4xl">
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-3xl font-bold text-gray-800">
              Agentic Fullstack Template
            </h1>
            <p className="text-gray-600">
              Welcome, {session.user?.name || session.user?.email}
            </p>
          </div>
          <button
            onClick={() => signOut()}
            className="text-gray-600 hover:text-gray-800 underline"
          >
            Sign out
          </button>
        </div>
        <div className="h-[600px] border rounded-lg shadow-lg bg-white overflow-hidden">
          <CopilotChat
            className="h-full"
            labels={{
              title: "AI Assistant",
              initial: "Hello! How can I help you today?",
            }}
          />
        </div>
      </div>
    </main>
  );
}
