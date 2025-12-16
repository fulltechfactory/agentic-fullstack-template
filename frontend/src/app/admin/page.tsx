"use client";

import { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { 
  Activity, 
  Database, 
  Users, 
  FileText, 
  Server,
  CheckCircle,
  XCircle,
  RefreshCw
} from "lucide-react";
import { Button } from "@/components/ui/button";

interface Stats {
  total_sessions: number;
  total_knowledge_documents: number;
  ai_provider: string;
  environment: string;
}

interface Session {
  session_id: string;
  created_at: string;
  message_count: number;
}

interface Health {
  database: string;
  ai_provider: string;
}

export default function AdminPage() {
  const { data: session, status } = useSession();
  const [stats, setStats] = useState<Stats | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [recentSessions, setRecentSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchData = async () => {
    setLoading(true);
    setError(null);
    
    try {
      // Fetch stats
      const statsRes = await fetch("/api/admin/stats");
      if (statsRes.ok) {
        const statsData = await statsRes.json();
        setStats(statsData.stats);
        setRecentSessions(statsData.recent_sessions || []);
      } else {
        const err = await statsRes.json();
        setError(err.detail || "Failed to fetch stats");
      }

      // Fetch health
      const healthRes = await fetch("/api/admin/health");
      if (healthRes.ok) {
        const healthData = await healthRes.json();
        setHealth(healthData.health);
      }
    } catch (e) {
      setError("Network error");
    } finally {
      setLoading(false);
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

  // Check role access
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
            <h1 className="text-lg font-semibold">Administration</h1>
          </header>
          <main className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <h2 className="text-xl font-semibold mb-2">Access Denied</h2>
              <p className="text-muted-foreground">
                You need ADMIN role to access this page.
              </p>
            </div>
          </main>
        </SidebarInset>
      </SidebarProvider>
    );
  }

  const formatDate = (dateString: string) => {
    const timestamp = parseInt(dateString);
    if (!isNaN(timestamp)) {
      return new Date(timestamp * 1000).toLocaleString();
    }
    return new Date(dateString).toLocaleString();
  };

  const isHealthy = (status: string) => status.includes("healthy") || status.includes("configured");

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-2 h-4" />
          <h1 className="text-lg font-semibold">Administration</h1>
          <div className="ml-auto">
            <Button variant="outline" size="sm" onClick={fetchData} disabled={loading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          </div>
        </header>
        <main className="flex-1 p-6">
          <div className="max-w-6xl mx-auto space-y-6">
            {error && (
              <div className="p-4 rounded-lg bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                {error}
              </div>
            )}

            {/* System Health */}
            <section>
              <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
                <Activity className="h-5 w-5" />
                System Health
              </h2>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="p-4 border rounded-lg bg-card">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Database className="h-5 w-5 text-muted-foreground" />
                      <span className="font-medium">Database</span>
                    </div>
                    {health && (
                      <div className="flex items-center gap-2">
                        {isHealthy(health.database) ? (
                          <CheckCircle className="h-5 w-5 text-green-500" />
                        ) : (
                          <XCircle className="h-5 w-5 text-red-500" />
                        )}
                        <span className={`text-sm ${isHealthy(health.database) ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`}>
                          {health.database}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
                <div className="p-4 border rounded-lg bg-card">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <Server className="h-5 w-5 text-muted-foreground" />
                      <span className="font-medium">AI Provider</span>
                    </div>
                    {health && (
                      <div className="flex items-center gap-2">
                        {isHealthy(health.ai_provider) ? (
                          <CheckCircle className="h-5 w-5 text-green-500" />
                        ) : (
                          <XCircle className="h-5 w-5 text-red-500" />
                        )}
                        <span className={`text-sm ${isHealthy(health.ai_provider) ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`}>
                          {health.ai_provider}
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </section>

            {/* Statistics */}
            <section>
              <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
                <Activity className="h-5 w-5" />
                Statistics
              </h2>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="p-4 border rounded-lg bg-card">
                  <div className="flex items-center gap-3 mb-2">
                    <Users className="h-5 w-5 text-blue-500" />
                    <span className="text-sm text-muted-foreground">Total Sessions</span>
                  </div>
                  <p className="text-3xl font-bold">{stats?.total_sessions ?? "-"}</p>
                </div>
                <div className="p-4 border rounded-lg bg-card">
                  <div className="flex items-center gap-3 mb-2">
                    <FileText className="h-5 w-5 text-purple-500" />
                    <span className="text-sm text-muted-foreground">Knowledge Docs</span>
                  </div>
                  <p className="text-3xl font-bold">{stats?.total_knowledge_documents ?? "-"}</p>
                </div>
                <div className="p-4 border rounded-lg bg-card">
                  <div className="flex items-center gap-3 mb-2">
                    <Server className="h-5 w-5 text-green-500" />
                    <span className="text-sm text-muted-foreground">AI Provider</span>
                  </div>
                  <p className="text-xl font-bold">{stats?.ai_provider ?? "-"}</p>
                </div>
                <div className="p-4 border rounded-lg bg-card">
                  <div className="flex items-center gap-3 mb-2">
                    <Activity className="h-5 w-5 text-orange-500" />
                    <span className="text-sm text-muted-foreground">Environment</span>
                  </div>
                  <p className="text-xl font-bold">{stats?.environment ?? "-"}</p>
                </div>
              </div>
            </section>

            {/* Recent Sessions */}
            <section>
              <h2 className="text-lg font-semibold mb-4 flex items-center gap-2">
                <Users className="h-5 w-5" />
                Recent Sessions
              </h2>
              <div className="border rounded-lg overflow-hidden">
                <table className="w-full">
                  <thead className="bg-muted">
                    <tr>
                      <th className="text-left p-3 font-medium">Session ID</th>
                      <th className="text-left p-3 font-medium">Created</th>
                      <th className="text-left p-3 font-medium">Messages</th>
                    </tr>
                  </thead>
                  <tbody>
                    {recentSessions.length === 0 ? (
                      <tr>
                        <td colSpan={3} className="p-4 text-center text-muted-foreground">
                          No sessions yet
                        </td>
                      </tr>
                    ) : (
                      recentSessions.map((sess) => (
                        <tr key={sess.session_id} className="border-t">
                          <td className="p-3 font-mono text-sm">
                            {sess.session_id.substring(0, 8)}...
                          </td>
                          <td className="p-3 text-sm">
                            {sess.created_at ? formatDate(sess.created_at) : "-"}
                          </td>
                          <td className="p-3 text-sm">{sess.message_count}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
