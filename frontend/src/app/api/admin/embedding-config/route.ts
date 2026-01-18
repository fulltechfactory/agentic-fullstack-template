import { NextResponse } from "next/server";
import { auth } from "@/auth";

export async function GET() {
  const session = await auth();

  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  // Check role access
  const roles = (session?.user as { roles?: string[] })?.roles || [];
  const hasAccess = roles.includes("ADMIN");

  if (!hasAccess) {
    return NextResponse.json({ detail: "Forbidden" }, { status: 403 });
  }

  try {
    const response = await fetch(`${process.env.BACKEND_URL || "http://localhost:8000"}/api/admin/embedding-config`, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    });

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}
