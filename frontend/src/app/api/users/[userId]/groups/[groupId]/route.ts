import { NextResponse } from "next/server";
import { auth } from "@/auth";

export async function PUT(
  request: Request,
  { params }: { params: Promise<{ userId: string; groupId: string }> }
) {
  const session = await auth();
  
  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  const user = session.user as { id: string; roles?: string[] };
  const roles = user.roles || [];
  
  if (!roles.includes("ADMIN")) {
    return NextResponse.json({ detail: "Forbidden" }, { status: 403 });
  }

  const { userId, groupId } = await params;

  try {
    const response = await fetch(
      `${process.env.BACKEND_URL || "http://localhost:8000"}/api/users/${userId}/groups/${groupId}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-User-Roles": roles.join(","),
        },
      }
    );
    
    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ userId: string; groupId: string }> }
) {
  const session = await auth();
  
  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  const user = session.user as { id: string; roles?: string[] };
  const roles = user.roles || [];
  
  if (!roles.includes("ADMIN")) {
    return NextResponse.json({ detail: "Forbidden" }, { status: 403 });
  }

  const { userId, groupId } = await params;

  try {
    const response = await fetch(
      `${process.env.BACKEND_URL || "http://localhost:8000"}/api/users/${userId}/groups/${groupId}`,
      {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-User-Roles": roles.join(","),
        },
      }
    );
    
    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}
