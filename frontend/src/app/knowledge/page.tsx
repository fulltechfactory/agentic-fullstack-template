"use client";

import { useState } from "react";
import { useSession } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus, Search, Trash2, FileText } from "lucide-react";

interface KnowledgeResult {
  content: string;
  metadata: Record<string, unknown>;
}

export default function KnowledgePage() {
  const { data: session, status } = useSession();
  const [activeTab, setActiveTab] = useState<"add" | "search">("add");
  const [content, setContent] = useState("");
  const [name, setName] = useState("");
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<KnowledgeResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

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
  const hasAccess = roles.includes("RAG_SUPERVISOR") || roles.includes("ADMIN");

  if (!hasAccess) {
    return (
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
            <SidebarTrigger className="-ml-1" />
            <Separator orientation="vertical" className="mr-2 h-4" />
            <h1 className="text-lg font-semibold">Knowledge Base</h1>
          </header>
          <main className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <h2 className="text-xl font-semibold mb-2">Access Denied</h2>
              <p className="text-muted-foreground">
                You need RAG_SUPERVISOR or ADMIN role to access this page.
              </p>
            </div>
          </main>
        </SidebarInset>
      </SidebarProvider>
    );
  }

  const handleAdd = async () => {
    if (!content.trim()) return;
    
    setLoading(true);
    setMessage(null);
    
    try {
      const response = await fetch("/api/knowledge/add", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ content, name: name || undefined }),
      });
      
      if (response.ok) {
        setMessage({ type: "success", text: "Content added successfully!" });
        setContent("");
        setName("");
      } else {
        const error = await response.json();
        setMessage({ type: "error", text: error.detail || "Failed to add content" });
      }
    } catch {
      setMessage({ type: "error", text: "Network error" });
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!query.trim()) return;
    
    setLoading(true);
    setMessage(null);
    
    try {
      const response = await fetch("/api/knowledge/search", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ query, limit: 10 }),
      });
      
      if (response.ok) {
        const data = await response.json();
        setResults(data.results || []);
      } else {
        const error = await response.json();
        setMessage({ type: "error", text: error.detail || "Search failed" });
      }
    } catch {
      setMessage({ type: "error", text: "Network error" });
    } finally {
      setLoading(false);
    }
  };

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-2 h-4" />
          <h1 className="text-lg font-semibold">Knowledge Base Management</h1>
        </header>
        <main className="flex-1 p-6">
          <div className="max-w-4xl mx-auto">
            {/* Tabs */}
            <div className="flex gap-2 mb-6">
              <Button
                variant={activeTab === "add" ? "default" : "outline"}
                onClick={() => setActiveTab("add")}
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Content
              </Button>
              <Button
                variant={activeTab === "search" ? "default" : "outline"}
                onClick={() => setActiveTab("search")}
              >
                <Search className="h-4 w-4 mr-2" />
                Search
              </Button>
            </div>

            {/* Message */}
            {message && (
              <div
                className={`p-4 rounded-lg mb-6 ${
                  message.type === "success"
                    ? "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
                    : "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
                }`}
              >
                {message.text}
              </div>
            )}

            {/* Add Content Tab */}
            {activeTab === "add" && (
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Document Name (optional)
                  </label>
                  <Input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g., company_policy"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium mb-2">
                    Content
                  </label>
                  <textarea
                    value={content}
                    onChange={(e) => setContent(e.target.value)}
                    className="w-full h-48 p-3 border rounded-lg bg-background resize-none focus:outline-none focus:ring-2 focus:ring-ring"
                    placeholder="Enter the text content to add to the knowledge base..."
                  />
                </div>
                <Button onClick={handleAdd} disabled={loading || !content.trim()}>
                  {loading ? "Adding..." : "Add to Knowledge Base"}
                </Button>
              </div>
            )}

            {/* Search Tab */}
            {activeTab === "search" && (
              <div className="space-y-4">
                <div className="flex gap-2">
                  <Input
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Search the knowledge base..."
                    onKeyDown={(e) => e.key === "Enter" && handleSearch()}
                  />
                  <Button onClick={handleSearch} disabled={loading || !query.trim()}>
                    {loading ? "Searching..." : "Search"}
                  </Button>
                </div>

                {/* Results */}
                <div className="space-y-3">
                  {results.map((result, index) => (
                    <div
                      key={index}
                      className="p-4 border rounded-lg bg-card"
                    >
                      <div className="flex items-start gap-3">
                        <FileText className="h-5 w-5 text-muted-foreground mt-0.5" />
                        <div className="flex-1">
                          <p className="text-sm">{result.content}</p>
                          {Object.keys(result.metadata).length > 0 && (
                            <p className="text-xs text-muted-foreground mt-2">
                              Metadata: {JSON.stringify(result.metadata)}
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}
                  {results.length === 0 && query && !loading && (
                    <p className="text-muted-foreground text-center py-8">
                      No results found
                    </p>
                  )}
                </div>
              </div>
            )}
          </div>
        </main>
      </SidebarInset>
    </SidebarProvider>
  );
}
