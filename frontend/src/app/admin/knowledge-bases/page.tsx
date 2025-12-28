"use client";

import { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import {
  Database,
  Users,
  RefreshCw,
  Plus,
  Trash2,
  Shield,
  ChevronDown,
  ChevronUp,
} from "lucide-react";

interface KnowledgeBase {
  id: string;
  name: string;
  slug: string;
  description: string;
  group_name: string;
  created_by: string;
  created_at: string;
  is_active: boolean;
  document_count: number;
  permission: string;
}

interface Permission {
  id: string;
  group_name: string;
  user_id: string;
  permission: string;
  granted_by: string;
  created_at: string;
}

interface User {
  id: string;
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  enabled: boolean;
}

export default function KnowledgeBasesAdminPage() {
  const { data: session, status } = useSession();
  const [kbs, setKbs] = useState<KnowledgeBase[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [usersMap, setUsersMap] = useState<Record<string, User>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [expandedKb, setExpandedKb] = useState<string | null>(null);
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [permissionsLoading, setPermissionsLoading] = useState(false);

  // New permission form
  const [selectedUserId, setSelectedUserId] = useState("");
  const [newPermission, setNewPermission] = useState<"READ" | "WRITE">("WRITE");

  const fetchUsers = async () => {
    try {
      const res = await fetch("/api/users");
      if (res.ok) {
        const data = await res.json();
        const usersList = data.users || [];
        setUsers(usersList);
        const map: Record<string, User> = {};
        usersList.forEach((u: User) => {
          map[u.id] = u;
        });
        setUsersMap(map);
      }
    } catch (e) {
      console.error("Failed to fetch users", e);
    }
  };

  const fetchKbs = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch("/api/kb");
      if (res.ok) {
        const data = await res.json();
        setKbs(data.knowledge_bases || []);
      } else {
        const err = await res.json();
        setError(err.detail || "Failed to fetch knowledge bases");
      }
    } catch (e) {
      setError("Network error");
    } finally {
      setLoading(false);
    }
  };

  const fetchPermissions = async (groupName: string) => {
    setPermissionsLoading(true);
    try {
      const encodedGroup = encodeURIComponent(groupName.replace("/", ""));
      const res = await fetch("/api/kb/groups/" + encodedGroup + "/permissions");
      if (res.ok) {
        const data = await res.json();
        setPermissions(data.permissions || []);
      }
    } catch (e) {
      console.error("Failed to fetch permissions", e);
    } finally {
      setPermissionsLoading(false);
    }
  };

  const toggleExpand = async (kb: KnowledgeBase) => {
    if (expandedKb === kb.id) {
      setExpandedKb(null);
      setPermissions([]);
    } else {
      setExpandedKb(kb.id);
      setSelectedUserId("");
      await fetchPermissions(kb.group_name);
    }
  };

  const addPermission = async (groupName: string) => {
    if (!selectedUserId) return;
    
    try {
      const encodedGroup = encodeURIComponent(groupName.replace("/", ""));
      const res = await fetch("/api/kb/groups/" + encodedGroup + "/permissions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: selectedUserId,
          permission: newPermission,
        }),
      });
      
      if (res.ok) {
        setSelectedUserId("");
        await fetchPermissions(groupName);
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to add permission");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  const removePermission = async (groupName: string, permId: string) => {
    if (!confirm("Remove this permission?")) return;
    
    try {
      const encodedGroup = encodeURIComponent(groupName.replace("/", ""));
      const res = await fetch("/api/kb/groups/" + encodedGroup + "/permissions/" + permId, {
        method: "DELETE",
      });
      
      if (res.ok) {
        await fetchPermissions(groupName);
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to remove permission");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  const getUserDisplay = (userId: string) => {
    const user = usersMap[userId];
    if (user) {
      return user.firstName + " " + user.lastName + " (" + user.username + ")";
    }
    return userId.substring(0, 8) + "...";
  };

  useEffect(() => {
    if (session) {
      fetchUsers();
      fetchKbs();
    }
  }, [session]);

  if (status === "loading") {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center">
        <div className="text-muted-foreground">Loading...</div>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center">
        <div className="text-muted-foreground">Please sign in to access this page.</div>
      </main>
    );
  }

  const roles = (session?.user as { roles?: string[] })?.roles || [];
  const hasAccess = roles.includes("ADMIN");

  if (!hasAccess) {
    return (
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
            <SidebarTrigger className="-ml-1" />
            <Separator orientation="vertical" className="mr-2 h-4" />
            <h1 className="text-lg font-semibold">Knowledge Bases</h1>
          </header>
          <main className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <h2 className="text-xl font-semibold mb-2">Access Denied</h2>
              <p className="text-muted-foreground">You need ADMIN role to access this page.</p>
            </div>
          </main>
        </SidebarInset>
      </SidebarProvider>
    );
  }

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-2 h-4" />
          <h1 className="text-lg font-semibold">Knowledge Bases Management</h1>
          <div className="ml-auto">
            <Button variant="outline" size="sm" onClick={() => { fetchUsers(); fetchKbs(); }} disabled={loading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          </div>
        </header>
        <main className="flex-1 p-6">
          <div className="max-w-4xl mx-auto space-y-6">
            {error && (
              <div className="p-4 rounded-lg bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                {error}
              </div>
            )}

            <div className="p-4 rounded-lg bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200">
              <p className="text-sm">
                <strong>Note:</strong> As an admin, you can manage permissions but cannot access document contents.
              </p>
            </div>

            <section>
              <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
                <Database className="h-5 w-5" />
                Knowledge Bases
              </h2>
              
              <div className="space-y-4">
                {kbs.length === 0 ? (
                  <p className="text-muted-foreground">No knowledge bases found.</p>
                ) : (
                  kbs.map((kb) => (
                    <div key={kb.id} className="border rounded-lg bg-card">
                      <div
                        className="p-4 flex items-center justify-between cursor-pointer hover:bg-muted/50"
                        onClick={() => toggleExpand(kb)}
                      >
                        <div className="flex items-center gap-4">
                          <Database className="h-5 w-5 text-blue-500" />
                          <div>
                            <h3 className="font-medium">{kb.name}</h3>
                            <p className="text-sm text-muted-foreground">
                              Group: {kb.group_name} • {kb.document_count} documents
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-xs px-2 py-1 rounded bg-muted">
                            {kb.slug}
                          </span>
                          {expandedKb === kb.id ? (
                            <ChevronUp className="h-4 w-4" />
                          ) : (
                            <ChevronDown className="h-4 w-4" />
                          )}
                        </div>
                      </div>
                      
                      {expandedKb === kb.id && (
                        <div className="border-t p-4 space-y-4">
                          <div>
                            <h4 className="font-medium mb-2 flex items-center gap-2">
                              <Shield className="h-4 w-4" />
                              Permissions for {kb.group_name}
                            </h4>
                            <p className="text-sm text-muted-foreground mb-4">
                              Members of {kb.group_name} have implicit READ access. Add WRITE for document management or READ for cross-group access.
                            </p>
                            
                            {permissionsLoading ? (
                              <p className="text-sm text-muted-foreground">Loading permissions...</p>
                            ) : (
                              <div className="space-y-2">
                                {permissions.length === 0 ? (
                                  <p className="text-sm text-muted-foreground">No explicit permissions configured.</p>
                                ) : (
                                  permissions.map((perm) => (
                                    <div
                                      key={perm.id}
                                      className="flex items-center justify-between p-2 rounded bg-muted"
                                    >
                                      <div className="flex items-center gap-2">
                                        <Users className="h-4 w-4" />
                                        <span className="text-sm">{getUserDisplay(perm.user_id)}</span>
                                        <span
                                          className={`text-xs px-2 py-0.5 rounded ${
                                            perm.permission === "WRITE"
                                              ? "bg-green-200 text-green-800 dark:bg-green-900 dark:text-green-200"
                                              : "bg-blue-200 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
                                          }`}
                                        >
                                          {perm.permission}
                                        </span>
                                      </div>
                                      <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={() => removePermission(kb.group_name, perm.id)}
                                      >
                                        <Trash2 className="h-4 w-4 text-red-500" />
                                      </Button>
                                    </div>
                                  ))
                                )}
                              </div>
                            )}

                            <div className="mt-4 flex gap-2">
                              <select
                                value={selectedUserId}
                                onChange={(e) => setSelectedUserId(e.target.value)}
                                className="flex-1 px-3 py-2 border rounded-md bg-background"
                              >
                                <option value="">Select a user...</option>
                                {users.map((u) => (
                                  <option key={u.id} value={u.id}>
                                    {u.firstName} {u.lastName} ({u.username})
                                  </option>
                                ))}
                              </select>
                              <select
                                value={newPermission}
                                onChange={(e) => setNewPermission(e.target.value as "READ" | "WRITE")}
                                className="px-3 py-2 border rounded-md bg-background"
                              >
                                <option value="WRITE">WRITE</option>
                                <option value="READ">READ (cross-group)</option>
                              </select>
                              <Button onClick={() => addPermission(kb.group_name)} disabled={!selectedUserId}>
                                <Plus className="h-4 w-4 mr-1" />
                                Add
                              </Button>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  ))
                )}
              </div>
            </section>
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
