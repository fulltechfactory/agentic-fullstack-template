"use client"
import * as React from "react"
import {
  Bot,
  BookOpen,
  Settings,
  MessageSquare,
  Database,
  Users,
} from "lucide-react"
import { useSession } from "next-auth/react"
import { NavMain } from "@/components/nav-main"
import { NavConversations } from "@/components/nav-conversations"
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
const getNavItems = (roles: string[], groups: string[]) => {
  const items = []

  // Knowledge Base - visible to users with groups (non-ADMIN only)
  if (groups.length > 0 && !roles.includes("ADMIN")) {
    items.push({
      title: "Knowledge Base",
      url: "/knowledge",
      icon: BookOpen,
    })
  }

  // Admin section - visible to ADMIN only
  if (roles.includes("ADMIN")) {
    items.push({
      title: "Administration",
      url: "/admin",
      icon: Settings,
    })
    items.push({
      title: "Users & Groups",
      url: "/admin/users",
      icon: Users,
    })
    items.push({
      title: "KB Management",
      url: "/admin/knowledge-bases",
      icon: Database,
    })
  }

  return items
}

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  const { data: session } = useSession()
  const user = session?.user as {
    name?: string;
    email?: string;
    roles?: string[];
    groups?: string[]
  } | undefined
  
  const roles = user?.roles || []
  const groups = user?.groups || []
  const navItems = getNavItems(roles, groups)
  
  const userData = {
    name: user?.name || "User",
    email: user?.email || "",
    avatar: "",
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
                  <span className="truncate font-semibold">Keystone</span>
                  <span className="truncate text-xs">AI Assistant</span>
                </div>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      <SidebarContent>
        <NavConversations />
        {navItems.length > 0 && <NavMain items={navItems} />}
      </SidebarContent>
      <SidebarFooter>
        <ThemeToggle />
        <NavUser user={userData} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
