"use client";

import { CopilotChat } from "@copilotkit/react-ui";
import "@copilotkit/react-ui/styles.css";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8 bg-gray-50">
      <div className="w-full max-w-4xl">
        <h1 className="text-3xl font-bold text-center mb-8 text-gray-800">
          Agentic Fullstack Template
        </h1>
        <p className="text-center text-gray-600 mb-8">
          AI-powered application built with CopilotKit and Agno
        </p>
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
