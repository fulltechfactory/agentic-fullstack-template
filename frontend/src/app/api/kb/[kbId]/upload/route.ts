import { NextResponse } from "next/server";
import { auth } from "@/auth";

export async function POST(
  request: Request,
  { params }: { params: Promise<{ kbId: string }> }
) {
  const session = await auth();
  
  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  const user = session.user as { id: string; roles?: string[]; groups?: string[] };
  const roles = user.roles || [];
  const groups = user.groups || [];
  const { kbId } = await params;

  try {
    const formData = await request.formData();
    
    const response = await fetch(
      `${process.env.BACKEND_URL || "http://localhost:8000"}/api/kb/${kbId}/upload`,
      {
        method: "POST",
        headers: {
          "X-User-ID": user.id,
          "X-User-Groups": groups.join(","),
          "X-User-Roles": roles.join(","),
        },
        body: formData,
      }
    );
    
    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}
