"use client";

import { useState, useEffect } from "react";
import { useSession } from "next-auth/react";
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Input } from "@/components/ui/input";
import {
  BookOpen,
  FileText,
  RefreshCw,
  Plus,
  Trash2,
  ChevronDown,
  ChevronUp,
  Send,
  Eye,
  Edit,
} from "lucide-react";

interface KnowledgeBase {
  id: string;
  name: string;
  slug: string;
  description: string;
  group_name: string;
  document_count: number;
  permission: string;
}

interface Document {
  id: string;
  name: string;
  content: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

export default function KnowledgePage() {
  const { data: session, status } = useSession();
  const [kbs, setKbs] = useState<KnowledgeBase[]>([]);
  const [selectedKb, setSelectedKb] = useState<KnowledgeBase | null>(null);
  const [documents, setDocuments] = useState<Document[]>([]);
  const [loading, setLoading] = useState(true);
  const [docsLoading, setDocsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Add document form
  const [showAddForm, setShowAddForm] = useState(false);
  const [newDocName, setNewDocName] = useState("");
  const [newDocContent, setNewDocContent] = useState("");
  const [adding, setAdding] = useState(false);

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

  const fetchDocuments = async (kbId: string) => {
    setDocsLoading(true);
    try {
      const res = await fetch(`/api/kb/${kbId}/documents`);
      if (res.ok) {
        const data = await res.json();
        setDocuments(data.documents || []);
      } else {
        const err = await res.json();
        setError(err.detail || "Failed to fetch documents");
        setDocuments([]);
      }
    } catch (e) {
      setError("Network error");
      setDocuments([]);
    } finally {
      setDocsLoading(false);
    }
  };

  const selectKb = async (kb: KnowledgeBase) => {
    setSelectedKb(kb);
    setShowAddForm(false);
    await fetchDocuments(kb.id);
  };

  const addDocument = async () => {
    if (!selectedKb || !newDocContent.trim()) return;
    
    setAdding(true);
    try {
      const res = await fetch(`/api/kb/${selectedKb.id}/documents`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          content: newDocContent.trim(),
          name: newDocName.trim() || undefined,
        }),
      });
      
      if (res.ok) {
        setNewDocName("");
        setNewDocContent("");
        setShowAddForm(false);
        await fetchDocuments(selectedKb.id);
        // Refresh KB list to update document count
        await fetchKbs();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to add document");
      }
    } catch (e) {
      alert("Network error");
    } finally {
      setAdding(false);
    }
  };

  const deleteDocument = async (docId: string) => {
    if (!selectedKb) return;
    if (!confirm("Delete this document?")) return;
    
    try {
      const res = await fetch(`/api/kb/${selectedKb.id}/documents/${docId}`, {
        method: "DELETE",
      });
      
      if (res.ok) {
        await fetchDocuments(selectedKb.id);
        await fetchKbs();
      } else {
        const err = await res.json();
        alert(err.detail || "Failed to delete document");
      }
    } catch (e) {
      alert("Network error");
    }
  };

  useEffect(() => {
    if (session) {
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

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset>
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <SidebarTrigger className="-ml-1" />
          <Separator orientation="vertical" className="mr-2 h-4" />
          <h1 className="text-lg font-semibold">Knowledge Base</h1>
          <div className="ml-auto">
            <Button variant="outline" size="sm" onClick={fetchKbs} disabled={loading}>
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

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* KB List */}
              <div className="space-y-4">
                <h2 className="font-semibold flex items-center gap-2">
                  <BookOpen className="h-4 w-4" />
                  My Knowledge Bases
                </h2>
                
                {loading ? (
                  <p className="text-sm text-muted-foreground">Loading...</p>
                ) : kbs.length === 0 ? (
                  <p className="text-sm text-muted-foreground">No knowledge bases available.</p>
                ) : (
                  <div className="space-y-2">
                    {kbs.map((kb) => (
                      <div
                        key={kb.id}
                        onClick={() => selectKb(kb)}
                        className={`p-3 border rounded-lg cursor-pointer transition-colors ${
                          selectedKb?.id === kb.id
                            ? "border-primary bg-primary/5"
                            : "hover:bg-muted/50"
                        }`}
                      >
                        <div className="flex items-center justify-between">
                          <span className="font-medium">{kb.name}</span>
                          <span
                            className={`text-xs px-2 py-0.5 rounded ${
                              kb.permission === "WRITE"
                                ? "bg-green-200 text-green-800 dark:bg-green-900 dark:text-green-200"
                                : "bg-blue-200 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
                            }`}
                          >
                            {kb.permission === "WRITE" ? (
                              <span className="flex items-center gap-1">
                                <Edit className="h-3 w-3" /> Write
                              </span>
                            ) : (
                              <span className="flex items-center gap-1">
                                <Eye className="h-3 w-3" /> Read
                              </span>
                            )}
                          </span>
                        </div>
                        <p className="text-xs text-muted-foreground mt-1">
                          {kb.document_count} documents • {kb.group_name}
                        </p>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Documents */}
              <div className="md:col-span-2 space-y-4">
                {selectedKb ? (
                  <>
                    <div className="flex items-center justify-between">
                      <h2 className="font-semibold flex items-center gap-2">
                        <FileText className="h-4 w-4" />
                        Documents in {selectedKb.name}
                      </h2>
                      {selectedKb.permission === "WRITE" && (
                        <Button
                          size="sm"
                          onClick={() => setShowAddForm(!showAddForm)}
                        >
                          <Plus className="h-4 w-4 mr-1" />
                          Add Document
                        </Button>
                      )}
                    </div>

                    {/* Add Document Form */}
                    {showAddForm && selectedKb.permission === "WRITE" && (
                      <div className="p-4 border rounded-lg bg-muted/30 space-y-3">
                        <Input
                          placeholder="Document name (optional)"
                          value={newDocName}
                          onChange={(e) => setNewDocName(e.target.value)}
                        />
                        <Textarea
                          placeholder="Document content..."
                          value={newDocContent}
                          onChange={(e) => setNewDocContent(e.target.value)}
                          rows={5}
                        />
                        <div className="flex gap-2 justify-end">
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setShowAddForm(false)}
                          >
                            Cancel
                          </Button>
                          <Button
                            size="sm"
                            onClick={addDocument}
                            disabled={adding || !newDocContent.trim()}
                          >
                            {adding ? (
                              <RefreshCw className="h-4 w-4 mr-1 animate-spin" />
                            ) : (
                              <Send className="h-4 w-4 mr-1" />
                            )}
                            Add
                          </Button>
                        </div>
                      </div>
                    )}

                    {/* Documents List */}
                    {docsLoading ? (
                      <p className="text-sm text-muted-foreground">Loading documents...</p>
                    ) : documents.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No documents in this knowledge base.</p>
                    ) : (
                      <div className="space-y-3">
                        {documents.map((doc) => (
                          <div key={doc.id} className="p-4 border rounded-lg bg-card">
                            <div className="flex items-start justify-between">
                              <div className="flex-1">
                                <h4 className="font-medium">{doc.name || "Untitled"}</h4>
                                <p className="text-sm text-muted-foreground mt-1 whitespace-pre-wrap">
                                  {doc.content}
                                </p>
                                <p className="text-xs text-muted-foreground mt-2">
                                  Added: {doc.created_at ? new Date(doc.created_at).toLocaleString() : "Unknown"}
                                </p>
                              </div>
                              {selectedKb.permission === "WRITE" && (
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  onClick={() => deleteDocument(doc.id)}
                                >
                                  <Trash2 className="h-4 w-4 text-red-500" />
                                </Button>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </>
                ) : (
                  <div className="flex items-center justify-center h-64 text-muted-foreground">
                    Select a knowledge base to view documents
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
