import { NextRequest, NextResponse } from "next/server";
import { auth } from "@/auth";

export async function POST(request: NextRequest) {
  const session = await auth();

  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  // Check role access
  const roles = (session?.user as { roles?: string[] })?.roles || [];
  const hasAccess = roles.includes("RAG_SUPERVISOR") || roles.includes("ADMIN");

  if (!hasAccess) {
    return NextResponse.json({ detail: "Forbidden" }, { status: 403 });
  }

  try {
    const body = await request.json();

    const response = await fetch(`${process.env.BACKEND_URL || "http://localhost:8000"}/api/knowledge/add`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}
