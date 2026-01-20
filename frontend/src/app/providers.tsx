"use client";

import { SessionProvider } from "next-auth/react";
import { ReactNode } from "react";
import { ConversationsProvider } from "@/contexts/conversations-context";

interface ProvidersProps {
  children: ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <SessionProvider>
      <ConversationsProvider>
        {children}
      </ConversationsProvider>
    </SessionProvider>
  );
}
