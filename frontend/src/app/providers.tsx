"use client";

import { CopilotKit } from "@copilotkit/react-core";
import { SessionProvider } from "next-auth/react";
import { ReactNode } from "react";

interface ProvidersProps {
  children: ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <SessionProvider>
      <CopilotKit runtimeUrl="/api/copilotkit" agent="agent">
        {children}
      </CopilotKit>
    </SessionProvider>
  );
}
