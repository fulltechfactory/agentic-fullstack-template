import { HttpAgent } from "@ag-ui/client";
import {
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { NextRequest } from "next/server";
import { auth } from "@/auth";

const backendUrl = process.env.BACKEND_URL || "http://localhost:8000";
console.log("[CopilotKit] Backend URL:", backendUrl);

const serviceAdapter = new ExperimentalEmptyAdapter();

export const POST = async (req: NextRequest) => {
  // Get user session for context
  const session = await auth();
  const user = session?.user as { id?: string; roles?: string[]; groups?: string[] } | undefined;

  const userId = user?.id || "";
  const userGroups = user?.groups || [];
  const userRoles = user?.roles || [];

  console.log("[CopilotKit] User context:", { userId, userGroups, userRoles });

  // Create agent per-request with user headers
  const agent = new HttpAgent({
    url: `${backendUrl}/agui`,
    agentId: "agent",
    headers: {
      "X-User-ID": userId,
      "X-User-Groups": userGroups.join(","),
      "X-User-Roles": userRoles.join(","),
    },
  });

  // Create runtime per-request
  const runtime = new CopilotRuntime({
    agents: {
      agent,
    },
  });

  // Clone request to read body for logging
  const clonedReq = req.clone();
  const body = await clonedReq.text();
  console.log("[CopilotKit] Incoming request body:", body.substring(0, 500));

  const { handleRequest } = copilotRuntimeNextJSAppRouterEndpoint({
    runtime,
    serviceAdapter,
    endpoint: "/api/copilotkit",
  });

  try {
    console.log("[CopilotKit] Calling handleRequest...");
    const response = await handleRequest(req);
    console.log("[CopilotKit] Response status:", response.status);
    console.log("[CopilotKit] Response headers:", Object.fromEntries(response.headers.entries()));
    return response;
  } catch (error) {
    console.error("[CopilotKit] Error in handleRequest:", error);
    throw error;
  }
};
