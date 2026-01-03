import { HttpAgent } from "@ag-ui/client";
import {
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { NextRequest } from "next/server";
import { auth } from "@/auth";

const backendUrl = process.env.BACKEND_URL || "http://localhost:8000"\;

export const POST = async (req: NextRequest) => {
  // Get user session
  const session = await auth();
  
  // Prepare headers with user context
  const headers: Record<string, string> = {};
  if (session?.user) {
    headers["X-User-ID"] = session.user.id || "";
    headers["X-User-Groups"] = (session.user.groups || []).join(",");
    headers["X-User-Roles"] = (session.user.roles || []).join(",");
  }
  
  // Create agent with user headers
  const agent = new HttpAgent({
    url: `${backendUrl}/agui`,
    headers,
  });

  const runtime = new CopilotRuntime({
    agents: {
      agent,
    },
  });

  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter: new ExperimentalEmptyAdapter(),
    endpoint: "/api/copilotkit",
  });

  return handleRequest(req);
};
