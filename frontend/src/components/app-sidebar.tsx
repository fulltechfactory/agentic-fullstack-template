"use client"

import * as React from "react"
import {
  Bot,
  BookOpen,
  Settings,
  MessageSquare,
} from "lucide-react"
import { useSession } from "next-auth/react"

import { NavMain } from "@/components/nav-main"
import { NavUser } from "@/components/nav-user"
import { ThemeToggle } from "@/components/theme-toggle"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuItem,
  SidebarMenuButton,
  SidebarRail,
} from "@/components/ui/sidebar"

// Role-based navigation configuration
const getNavItems = (roles: string[]) => {
  const items = []

  // Chat - visible to all authenticated users
  items.push({
    title: "Chat",
    url: "/",
    icon: MessageSquare,
    isActive: true,
  })

  // Knowledge Base - visible to RAG_SUPERVISOR and ADMIN
  if (roles.includes("RAG_SUPERVISOR") || roles.includes("ADMIN")) {
    items.push({
      title: "Knowledge Base",
      url: "/knowledge",
      icon: BookOpen,
    })
  }

  // Admin - visible to ADMIN only
  if (roles.includes("ADMIN")) {
    items.push({
      title: "Administration",
      url: "/admin",
      icon: Settings,
    })
  }

  return items
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const { data: session } = useSession()
  
  // Extract roles from session (we'll add this to the session type)
  const roles = (session?.user as { roles?: string[] })?.roles || []
  const navItems = getNavItems(roles)

  const user = {
    name: session?.user?.name || "User",
    email: session?.user?.email || "",
    avatar: session?.user?.image || "",
  }

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton size="lg" asChild>
              <a href="/">
                <div className="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
                  <Bot className="size-4" />
                </div>
                <div className="grid flex-1 text-left text-sm leading-tight">
                  <span className="truncate font-semibold">Agentic App</span>
                  <span className="truncate text-xs">AI Assistant</span>
                </div>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navItems} />
      </SidebarContent>
      <SidebarFooter>
        <div className="flex items-center justify-between px-2 py-2">
          <ThemeToggle />
        </div>
        <NavUser user={user} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
