# Keystone

A fullstack template for building AI-powered applications with CopilotKit and Agno.

## Features

- **Multi-provider AI**: OpenAI, Anthropic, Google Gemini, Mistral, Ollama, LM Studio
- **Session Memory**: Conversation history persisted in PostgreSQL
- **Multi-KB RAG**: Multiple knowledge bases with group-based access control
- **Group-based Access Control**: Keycloak groups with READ/WRITE permissions per KB
- **Admin Dashboard**: System health, statistics, KB and permissions management
- **Modern UI**: shadcn/ui components with dark/light theme support
- **Authentication**: Keycloak + NextAuth.js with secure OAuth2/OIDC
- **AG-UI Protocol**: Real-time streaming communication between frontend and backend
- **Source Citations**: AI responses cite document sources from knowledge base
- **Multi-cloud ready**: Infrastructure as Code for AWS, GCP, Azure (OpenTofu)

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 15, React 19, TypeScript, CopilotKit, shadcn/ui |
| Backend | Python 3.11, Agno, FastAPI |
| Protocol | AG-UI (Agent-User Interaction) |
| Auth | Keycloak + NextAuth.js |
| Database | PostgreSQL 16 + PgVector |
| Infrastructure | Docker, OpenTofu |

## Prerequisites

- **Node.js** 18+ (recommended: 20+)
- **pnpm** 9+ (install with `npm install -g pnpm`)
- **Docker** and Docker Compose
- **Git**

### Optional (for local AI)

- **Ollama** for local LLM inference (https://ollama.ai)

## Quick Start

### 1. Clone the repository
```bash
git clone git@github.com:fulltechfactory/keystone.git
cd keystone
```

### 2. Configure the environment
```bash
# For cloud provider (OpenAI recommended for RAG embeddings)
make setup-dev AI_PROVIDER=openai AI_API_KEY=sk-your-key

# Or with Ollama (RAG requires OpenAI for embeddings)
make setup-dev AI_PROVIDER=ollama AI_URL=http://host.docker.internal:11434
```

### 3. Start the backend services
```bash
make dev-up
```

This starts:
- PostgreSQL + PgVector on `localhost:5432`
- Keycloak on `http://localhost:8080`
- Backend API on `http://localhost:8000`

Wait ~1 minute for Keycloak to initialize the realm and users.

### 4. Start the frontend
```bash
make frontend
```

### 5. Access the application

Open `http://localhost:3000` and sign in with one of the test users.

## User Roles & Groups

The application implements group-based access control with Keycloak groups.

### Roles

| Role | Description |
|------|-------------|
| `USER` | Access to chat and knowledge bases based on group membership |
| `ADMIN` | Manage users, groups, KBs and permissions (no access to KB content) |

### Groups

| Group | Description |
|-------|-------------|
| `/COMPANY` | All users (Company KB - shared knowledge) |
| `/RH` | HR department |
| `/FINANCE` | Finance department |

### Test Users

| User | Password | Role | Groups | Access |
|------|----------|------|--------|--------|
| `testuser` | `testuser` | USER | /COMPANY | Company KB (READ) |
| `rh_manager` | `rh_manager` | USER | /COMPANY, /RH | Company KB (READ), RH KB (WRITE) |
| `finance_manager` | `finance_manager` | USER | /COMPANY, /FINANCE | Company KB (READ), Finance KB (WRITE) |
| `adminuser` | `adminuser` | ADMIN | /COMPANY | KB Management, no content access |

### Permission Model

| Permission | Description |
|------------|-------------|
| **READ** (implicit) | All group members can query the KB via chat |
| **WRITE** (explicit) | User can add/modify/delete documents in the KB |
| **READ cross-group** | User can read a KB they're not a member of |

**Key principle**: ADMIN role manages access but cannot read document content.

## Multi-KB Architecture

The application supports multiple knowledge bases, each linked to a Keycloak group.

### How it works

1. Each KB is owned by a Keycloak group (e.g., `/RH` owns "RH KB")
2. Group members automatically have READ access to their KB
3. ADMIN grants WRITE permission to specific users
4. Users can receive cross-group READ access to other KBs
5. Chat searches all accessible KBs and cites sources in responses

### Knowledge Base Management

**For Users (Knowledge Base page):**
- View all accessible KBs with READ/WRITE badges
- Add documents to KBs with WRITE permission
- Delete documents from KBs with WRITE permission

**For Admins (KB Management page):**
- View all KBs with document counts
- Manage permissions (grant/revoke WRITE, add cross-group READ)
- Cannot access document content

### Creating a new KB

1. ADMIN creates a new group in Keycloak (e.g., `/LEGAL`)
2. ADMIN assigns users to the group
3. ADMIN grants WRITE permission to a user (e.g., legal_manager)
4. User with WRITE creates the KB via the Knowledge Base UI
5. Other group members can now query the KB

## Session Memory

The agent remembers conversation history across page refreshes and server restarts.

### How it works

1. User authenticates via Keycloak → receives a unique `user_id`
2. Frontend passes `user_id` as `threadId` to CopilotKit
3. Backend (Agno) stores conversation history in PostgreSQL
4. On each request, Agno loads the session history from the database

## RAG (Retrieval-Augmented Generation)

The agent searches accessible knowledge bases to answer questions with relevant context.

### How it works

1. Users with WRITE permission add documents via the Knowledge Base UI
2. Content is chunked and embedded using OpenAI `text-embedding-3-small`
3. Embeddings are stored in PostgreSQL with PgVector
4. On each query, relevant documents are retrieved from accessible KBs
5. The agent uses this context and **cites the source documents** in responses

### Knowledge API
```bash
# List accessible KBs
curl -X GET http://localhost:8000/api/kb \
  -H "X-User-ID: user-id" \
  -H "X-User-Groups: /COMPANY,/RH" \
  -H "X-User-Roles: USER"

# Add document to a KB (requires WRITE)
curl -X POST http://localhost:8000/api/kb/{kb_id}/documents \
  -H "Content-Type: application/json" \
  -H "X-User-ID: user-id" \
  -H "X-User-Groups: /COMPANY,/RH" \
  -H "X-User-Roles: USER" \
  -d '{"content": "Your text content here", "name": "document_name"}'

# List documents in a KB (requires READ)
curl -X GET http://localhost:8000/api/kb/{kb_id}/documents \
  -H "X-User-ID: user-id" \
  -H "X-User-Groups: /COMPANY,/RH" \
  -H "X-User-Roles: USER"
```

### Requirements

RAG requires OpenAI API key for embeddings (even when using other providers for chat).

## Administration

### Dashboard (`/admin`)

- **System Health**: Database connection status, AI provider configuration
- **Statistics**: Total sessions, knowledge documents count, environment info
- **Recent Sessions**: View latest chat sessions with message counts

### KB Management (`/admin/knowledge-bases`)

- View all knowledge bases with document counts
- Manage permissions per KB:
  - Grant WRITE permission to users
  - Grant cross-group READ access
  - Remove permissions

Access by signing in with `adminuser` / `adminuser`.

## UI Features

### Theme Support

The application supports light, dark, and system themes. Toggle via the sun/moon icon in the sidebar footer.

### Responsive Sidebar

- Collapsible sidebar with icon-only mode
- Role-based navigation items
- User profile with sign-out option

## Database

### Tables

| Table | Purpose |
|-------|---------|
| `app.agent_sessions` | Session data and conversation runs |
| `app.knowledge_bases` | KB metadata (name, slug, group) |
| `app.knowledge_embeddings` | RAG document embeddings (PgVector) |
| `app.knowledge_base_permissions` | WRITE and cross-group READ permissions |

### Default Credentials (dev/staging)

| User | Password | Purpose |
|------|----------|---------|
| postgres | postgres | Superuser (never used in app) |
| migration | migration | Schema migrations (DDL) |
| appuser | appuser | Application runtime (DML + DDL in dev) |
| keycloak | keycloak | Keycloak database access |

## Available Commands

### Setup Commands

| Command | Description |
|---------|-------------|
| `make setup-dev` | Configure local development environment |
| `make setup-staging` | Configure staging environment (cloud) |
| `make setup-deploy` | Configure production environment (cloud) |

### Docker Commands

| Command | Description |
|---------|-------------|
| `make dev-up` | Start backend services (PostgreSQL, Keycloak, Backend) |
| `make dev-down` | Stop all services |
| `make dev-logs` | Show container logs |
| `make dev-ps` | Show container status |
| `make dev-clean` | Remove all data and volumes |

### Frontend Commands

| Command | Description |
|---------|-------------|
| `make frontend` | Start frontend development server |
| `make frontend-install` | Install frontend dependencies |
| `make frontend-env` | Generate frontend/.env.local |

## AI Providers

| Provider | Type | Configuration |
|----------|------|---------------|
| OpenAI | Cloud | `AI_PROVIDER=openai AI_API_KEY=sk-...` |
| Anthropic | Cloud | `AI_PROVIDER=anthropic AI_API_KEY=sk-ant-...` |
| Google Gemini | Cloud | `AI_PROVIDER=gemini AI_API_KEY=...` |
| Mistral | Cloud | `AI_PROVIDER=mistral AI_API_KEY=...` |
| Ollama | Local | `AI_PROVIDER=ollama AI_URL=http://host.docker.internal:11434` |
| LM Studio | Local | `AI_PROVIDER=lmstudio AI_URL=http://host.docker.internal:1234` |

## Keycloak Admin Console

Access Keycloak admin at `http://localhost:8080` with:
- **Username:** `admin`
- **Password:** `admin`

## Roadmap

- [x] Multi-provider AI support
- [x] Authentication (Keycloak + NextAuth.js)
- [x] Session Memory (PostgreSQL)
- [x] RAG (Retrieval-Augmented Generation with PgVector)
- [x] Multi-KB with group-based access control
- [x] Modern UI with shadcn/ui
- [x] Dark/Light theme support
- [x] Admin dashboard (stats, health monitoring)
- [x] KB Management (permissions, WRITE/READ control)
- [x] Source citations in chat responses
- [ ] Admin user management (CRUD users, assign roles)
- [ ] KB selector in chat (filter by specific KB)
- [ ] User Memory (persistent user preferences)
- [ ] Infrastructure as Code (OpenTofu for AWS/GCP/Azure)
- [ ] Test suite (frontend, backend, infrastructure)

## Troubleshooting

### "Sign in with Keycloak" shows error

Clear your browser cookies for `localhost:3000` and try again.

### Keycloak not ready

Wait ~1 minute after `make dev-up` for Keycloak to fully initialize.

### Container fails to start
```bash
make dev-down
docker system prune -f
make dev-up
```

### Check service logs
```bash
docker logs keystone-postgres
docker logs keystone-keycloak
docker logs keystone-backend
docker logs keystone-keycloak-setup
```

### Reset all data
```bash
make dev-clean
make dev-up
```

## License

MIT
