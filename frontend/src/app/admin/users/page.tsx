"use client";

import { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Users,
  FolderTree,
  RefreshCw,
  Plus,
  Trash2,
  UserPlus,
  X,
  Check,
} from "lucide-react";

interface User {
  id: string;
  username: string;
  email: string;
  firstName: string;
  lastName: string;
  enabled: boolean;
  groups: string[];
}

interface Group {
  id: string;
  name: string;
  path: string;
  memberCount: number;
}

export default function AdminUsersPage() {
  const { data: session, status } = useSession();
  const [users, setUsers] = useState<User[]>([]);
  const [groups, setGroups] = useState<Group[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Create user form
  const [showCreateUser, setShowCreateUser] = useState(false);
  const [newUser, setNewUser] = useState({
    username: "",
    email: "",
    firstName: "",
    lastName: "",
    password: "",
    groups: ["/COMPANY"],
  });
  const [creatingUser, setCreatingUser] = useState(false);

  // Create group form
  const [showCreateGroup, setShowCreateGroup] = useState(false);
  const [newGroupName, setNewGroupName] = useState("");
  const [creatingGroup, setCreatingGroup] = useState(false);

  // Edit user groups
  const [editingUserId, setEditingUserId] = useState<string | null>(null);

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    try {
      const [usersRes, groupsRes] = await Promise.all([
        fetch("/api/users"),
        fetch("/api/groups"),
      ]);

      if (usersRes.ok) {
        const data = await usersRes.json();
        setUsers(data.users || []);
      } else {
        const err = await usersRes.json();
        setError(err.detail || "Failed to fetch users");
      }

      if (groupsRes.ok) {
        const data = await groupsRes.json();
        setGroups(data.groups || []);
      }
    } catch (e) {
      setError("Network error");
    } finally {
      setLoading(false);
    }
  };

  const createUser = async () => {
    if (!newUser.username || !newUser.email || !newUser.password) {
      alert("Username, email and password are required");
      return;
    }

    setCreatingUser(true);
    try {
      const res = await fetch("/api/users", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...newUser,
          roles: ["USER"],
        }),
      });

      if (res.ok) {
        setNewUser({
          username: "",
          email: "",
          firstName: "",
          lastName: "",
          password: "",
          groups: ["/COMPANY"],
        });
        setShowCreateUser(false);
        await fetchData();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to create user");
      }
    } catch (e) {
      alert("Network error");
    } finally {
      setCreatingUser(false);
    }
  };

  const deleteUser = async (userId: string, username: string) => {
    if (username === "adminuser") {
      alert("Cannot delete the admin user");
      return;
    }
    if (!confirm(`Delete user "${username}"?`)) return;

    try {
      const res = await fetch(`/api/users/${userId}`, { method: "DELETE" });
      if (res.ok) {
        await fetchData();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to delete user");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  const createGroup = async () => {
    if (!newGroupName.trim()) {
      alert("Group name is required");
      return;
    }

    setCreatingGroup(true);
    try {
      const res = await fetch("/api/groups", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: newGroupName }),
      });

      if (res.ok) {
        setNewGroupName("");
        setShowCreateGroup(false);
        await fetchData();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to create group");
      }
    } catch (e) {
      alert("Network error");
    } finally {
      setCreatingGroup(false);
    }
  };

  const deleteGroup = async (groupId: string, groupName: string) => {
    if (groupName === "COMPANY") {
      alert("Cannot delete the COMPANY group");
      return;
    }
    if (!confirm(`Delete group "${groupName}"?`)) return;

    try {
      const res = await fetch(`/api/groups/${groupId}`, { method: "DELETE" });
      if (res.ok) {
        await fetchData();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to delete group");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  const addUserToGroup = async (userId: string, groupId: string) => {
    try {
      const res = await fetch(`/api/users/${userId}/groups/${groupId}`, {
        method: "PUT",
      });
      if (res.ok) {
        await fetchData();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to add user to group");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  const removeUserFromGroup = async (userId: string, groupId: string, groupPath: string) => {
    if (groupPath === "/COMPANY") {
      alert("Cannot remove user from COMPANY group");
      return;
    }

    try {
      const res = await fetch(`/api/users/${userId}/groups/${groupId}`, {
        method: "DELETE",
      });
      if (res.ok) {
        await fetchData();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to remove user from group");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  const toggleUserGroup = (userId: string, group: Group, userGroups: string[]) => {
    if (userGroups.includes(group.path)) {
      removeUserFromGroup(userId, group.id, group.path);
    } else {
      addUserToGroup(userId, group.id);
    }
  };

  useEffect(() => {
    if (session) {
      fetchData();
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

  const user = session.user as { roles?: string[] };
  if (!user.roles?.includes("ADMIN")) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center">
        <div className="text-muted-foreground">Access denied. ADMIN role required.</div>
      </main>
    );
  }

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-2 h-4" />
          <h1 className="text-lg font-semibold">User & Group Management</h1>
          <div className="ml-auto">
            <Button variant="outline" size="sm" onClick={fetchData} disabled={loading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          </div>
        </header>
        <main className="flex-1 p-6">
          <div className="max-w-6xl mx-auto">
            {error && (
              <div className="mb-4 p-4 rounded-lg bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                {error}
              </div>
            )}

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Groups Section */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h2 className="font-semibold flex items-center gap-2">
                    <FolderTree className="h-4 w-4" />
                    Groups
                  </h2>
                  <Button size="sm" onClick={() => setShowCreateGroup(!showCreateGroup)}>
                    <Plus className="h-4 w-4 mr-1" />
                    New Group
                  </Button>
                </div>

                {showCreateGroup && (
                  <div className="p-4 border rounded-lg bg-muted/30 space-y-3">
                    <Input
                      placeholder="Group name (e.g., LEGAL, MARKETING)"
                      value={newGroupName}
                      onChange={(e) => setNewGroupName(e.target.value)}
                    />
                    <div className="flex gap-2 justify-end">
                      <Button variant="outline" size="sm" onClick={() => setShowCreateGroup(false)}>
                        Cancel
                      </Button>
                      <Button size="sm" onClick={createGroup} disabled={creatingGroup}>
                        {creatingGroup ? <RefreshCw className="h-4 w-4 mr-1 animate-spin" /> : <Plus className="h-4 w-4 mr-1" />}
                        Create
                      </Button>
                    </div>
                  </div>
                )}

                {loading ? (
                  <p className="text-sm text-muted-foreground">Loading...</p>
                ) : (
                  <div className="space-y-2">
                    {groups.map((group) => (
                      <div key={group.id} className="p-3 border rounded-lg flex items-center justify-between">
                        <div>
                          <span className="font-medium">{group.name}</span>
                          <span className="text-sm text-muted-foreground ml-2">
                            ({group.memberCount} members)
                          </span>
                        </div>
                        {group.name !== "COMPANY" && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => deleteGroup(group.id, group.name)}
                          >
                            <Trash2 className="h-4 w-4 text-red-500" />
                          </Button>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Users Section */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <h2 className="font-semibold flex items-center gap-2">
                    <Users className="h-4 w-4" />
                    Users
                  </h2>
                  <Button size="sm" onClick={() => setShowCreateUser(!showCreateUser)}>
                    <UserPlus className="h-4 w-4 mr-1" />
                    New User
                  </Button>
                </div>

                {showCreateUser && (
                  <div className="p-4 border rounded-lg bg-muted/30 space-y-3">
                    <div className="grid grid-cols-2 gap-2">
                      <Input
                        placeholder="Username *"
                        value={newUser.username}
                        onChange={(e) => setNewUser({ ...newUser, username: e.target.value })}
                      />
                      <Input
                        placeholder="Email *"
                        type="email"
                        value={newUser.email}
                        onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
                      />
                      <Input
                        placeholder="First name"
                        value={newUser.firstName}
                        onChange={(e) => setNewUser({ ...newUser, firstName: e.target.value })}
                      />
                      <Input
                        placeholder="Last name"
                        value={newUser.lastName}
                        onChange={(e) => setNewUser({ ...newUser, lastName: e.target.value })}
                      />
                    </div>
                    <Input
                      placeholder="Password *"
                      type="password"
                      value={newUser.password}
                      onChange={(e) => setNewUser({ ...newUser, password: e.target.value })}
                    />
                    <div className="flex gap-2 justify-end">
                      <Button variant="outline" size="sm" onClick={() => setShowCreateUser(false)}>
                        Cancel
                      </Button>
                      <Button size="sm" onClick={createUser} disabled={creatingUser}>
                        {creatingUser ? <RefreshCw className="h-4 w-4 mr-1 animate-spin" /> : <UserPlus className="h-4 w-4 mr-1" />}
                        Create
                      </Button>
                    </div>
                  </div>
                )}

                {loading ? (
                  <p className="text-sm text-muted-foreground">Loading...</p>
                ) : (
                  <div className="space-y-2">
                    {users.map((u) => (
                      <div key={u.id} className="p-3 border rounded-lg">
                        <div className="flex items-center justify-between">
                          <div>
                            <span className="font-medium">{u.username}</span>
                            <span className="text-sm text-muted-foreground ml-2">
                              {u.firstName} {u.lastName}
                            </span>
                          </div>
                          <div className="flex items-center gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => setEditingUserId(editingUserId === u.id ? null : u.id)}
                            >
                              {editingUserId === u.id ? <X className="h-4 w-4" /> : <FolderTree className="h-4 w-4" />}
                            </Button>
                            {u.username !== "adminuser" && (
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => deleteUser(u.id, u.username)}
                              >
                                <Trash2 className="h-4 w-4 text-red-500" />
                              </Button>
                            )}
                          </div>
                        </div>
                        <div className="flex flex-wrap gap-1 mt-2">
                          {u.groups.map((g) => (
                            <span
                              key={g}
                              className="text-xs px-2 py-0.5 rounded bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
                            >
                              {g}
                            </span>
                          ))}
                        </div>

                        {/* Edit groups */}
                        {editingUserId === u.id && (
                          <div className="mt-3 pt-3 border-t">
                            <p className="text-sm text-muted-foreground mb-2">Toggle groups:</p>
                            <div className="flex flex-wrap gap-2">
                              {groups.map((group) => (
                                <Button
                                  key={group.id}
                                  variant={u.groups.includes(group.path) ? "default" : "outline"}
                                  size="sm"
                                  onClick={() => toggleUserGroup(u.id, group, u.groups)}
                                  disabled={group.name === "COMPANY"}
                                >
                                  {u.groups.includes(group.path) ? (
                                    <Check className="h-3 w-3 mr-1" />
                                  ) : (
                                    <Plus className="h-3 w-3 mr-1" />
                                  )}
                                  {group.name}
                                </Button>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
