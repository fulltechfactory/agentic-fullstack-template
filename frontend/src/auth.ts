import NextAuth from "next-auth";
import Keycloak from "next-auth/providers/keycloak";

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Keycloak({
      clientId: process.env.KEYCLOAK_CLIENT_ID!,
      clientSecret: process.env.KEYCLOAK_CLIENT_SECRET!,
      issuer: process.env.NEXT_PUBLIC_KEYCLOAK_ISSUER || process.env.KEYCLOAK_ISSUER,
    }),
  ],
  callbacks: {
    async jwt({ token, account, profile }) {
      if (account) {
        token.accessToken = account.access_token;
        token.idToken = account.id_token;
        // Store Keycloak user ID (sub) from profile
        token.keycloakId = profile?.sub;
        
        // Extract roles from Keycloak token
        // Roles can be in realm_access or resource_access
        const realmRoles = (profile as { realm_access?: { roles?: string[] } })?.realm_access?.roles || [];
        const clientId = process.env.KEYCLOAK_CLIENT_ID!;
        const clientRoles = (profile as { resource_access?: Record<string, { roles?: string[] }> })?.resource_access?.[clientId]?.roles || [];
        
        // Combine realm and client roles
        token.roles = [...new Set([...realmRoles, ...clientRoles])];
      }
      return token;
    },
    async session({ session, token }) {
      session.accessToken = token.accessToken as string;
      // Use Keycloak ID instead of NextAuth generated ID
      session.user.id = (token.keycloakId as string) || token.sub!;
      // Add roles to session
      (session.user as { roles?: string[] }).roles = (token.roles as string[]) || [];
      return session;
    },
  },
});
