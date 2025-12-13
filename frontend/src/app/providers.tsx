"use client";

import { CopilotKit } from "@copilotkit/react-core";
import { ReactNode } from "react";

interface ProvidersProps {
  children: ReactNode;
}

export function Providers({ children }: ProvidersProps) {
  return (
    <CopilotKit
      runtimeUrl="/api/copilotkit"
      agent="agent"
    >
      {children}
    </CopilotKit>
  );
}
