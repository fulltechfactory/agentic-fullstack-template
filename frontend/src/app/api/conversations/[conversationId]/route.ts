import { NextResponse } from "next/server";
import { auth } from "@/auth";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ conversationId: string }> }
) {
  const session = await auth();

  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  const user = session.user as { id: string };
  const { conversationId } = await params;

  try {
    const response = await fetch(
      `${process.env.BACKEND_URL || "http://localhost:8000"}/api/conversations/${conversationId}`,
      {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "X-User-ID": user.id,
        },
      }
    );

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}

export async function PUT(
  request: Request,
  { params }: { params: Promise<{ conversationId: string }> }
) {
  const session = await auth();

  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  const user = session.user as { id: string };
  const { conversationId } = await params;

  try {
    const body = await request.json();
    const response = await fetch(
      `${process.env.BACKEND_URL || "http://localhost:8000"}/api/conversations/${conversationId}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-User-ID": user.id,
        },
        body: JSON.stringify(body),
      }
    );

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ conversationId: string }> }
) {
  const session = await auth();

  if (!session) {
    return NextResponse.json({ detail: "Unauthorized" }, { status: 401 });
  }

  const user = session.user as { id: string };
  const { conversationId } = await params;

  try {
    const response = await fetch(
      `${process.env.BACKEND_URL || "http://localhost:8000"}/api/conversations/${conversationId}`,
      {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "X-User-ID": user.id,
        },
      }
    );

    const data = await response.json();
    return NextResponse.json(data, { status: response.status });
  } catch {
    return NextResponse.json({ detail: "Backend error" }, { status: 500 });
  }
}
