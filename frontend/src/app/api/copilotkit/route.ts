import { HttpAgent } from "@ag-ui/client";
import {
  CopilotRuntime,
  ExperimentalEmptyAdapter,
  copilotRuntimeNextJSAppRouterEndpoint,
} from "@copilotkit/runtime";
import { NextRequest } from "next/server";

const backendUrl = process.env.BACKEND_URL || "http://localhost:8000";
console.log("[CopilotKit] Backend URL:", backendUrl);

// Create agent at module level (required for CopilotRuntime)
const agent = new HttpAgent({
  url: `${backendUrl}/agui`,
  agentId: "agent",
});

// Log when agent is created
console.log("[CopilotKit] HttpAgent created with URL:", `${backendUrl}/agui`);

// Create runtime at module level
const runtime = new CopilotRuntime({
  agents: {
    agent,
  },
});

const serviceAdapter = new ExperimentalEmptyAdapter();

export const POST = async (req: NextRequest) => {
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
