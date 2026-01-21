# Keystone

A fullstack template for building AI-powered applications with CopilotKit and Agno.

## Features

- **Multi-provider AI**: OpenAI, Anthropic, Google Gemini, Mistral, Azure OpenAI, Azure AI Foundry, Ollama, LM Studio
- **Multi-Conversations**: Multiple chat conversations per user with auto-generated titles
- **Session Memory**: Conversation history persisted in PostgreSQL
- **Multi-KB RAG**: Multiple knowledge bases with group-based access control
- **Personal Knowledge Bases**: Private KB for each user with configurable limits
- **Web Search**: Real-time information via DuckDuckGo integration
- **Smart PDF Processing**: Column-aware extraction for multi-column documents
- **Large File Support**: Automatic chunking for documents up to 200MB
- **File Upload**: Support for PDF, Word, Markdown, Text, and 20+ code file formats
- **Batch Operations**: Delete multiple documents or conversations at once
- **Group-based Access Control**: Keycloak groups with READ/WRITE permissions per KB
- **Admin Dashboard**: User & group management, KB permissions, system health
- **Modern UI**: shadcn/ui components with dark/light theme support
- **Authentication**: Keycloak + NextAuth.js with secure OAuth2/OIDC
- **AG-UI Protocol**: Real-time streaming communication between frontend and backend
- **Source Citations**: AI responses cite document sources from knowledge base
- **Multi-cloud Deployment**: Infrastructure as Code for AWS and Azure (OpenTofu)

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
git clone git@github.com:fulltechfactory/agentic-fullstack-template.git keystone
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

Wait ~1 minute for Keycloak to initialize.

### 4. Start the frontend
```bash
make frontend
```

### 5. Access the application

Open `http://localhost:3000` and sign in with `adminuser` / `adminuser`.

## Cloud Deployment

Keystone supports production deployment on multiple cloud providers using OpenTofu (Infrastructure as Code).

### Supported Platforms

| Provider | Infrastructure Type | Status | Documentation |
|----------|---------------------|--------|---------------|
| **AWS** | VM + Attached Storage | ✅ Ready | [RUNBOOK_AWS.md](docs/RUNBOOK_AWS.md) |
| **Azure** | VM + Attached Storage | ✅ Ready | [RUNBOOK_AZURE.md](docs/RUNBOOK_AZURE.md) |
| **GCP** | VM + Attached Storage | 🚧 Planned | - |
| **Scaleway** | VM + Attached Storage | 🚧 Planned | - |

### Quick Deploy

```bash
# Configure production environment
make setup-deploy

# Initialize OpenTofu
make infra-init

# Preview infrastructure
make infra-plan

# Deploy
make infra-apply
```

### Architecture (vm-attached-storage)

Single VM deployment with all services (PostgreSQL, Keycloak, Backend, Frontend) running on one instance with an attached persistent disk.

**Best suited for:**
- Small to medium deployments (< 100 concurrent users)
- Development/staging environments
- Cost-conscious production (~$30-35/month)

```
┌─────────────────────────────────────────┐
│              Cloud VM                    │
│  ┌─────────────────────────────────┐    │
│  │           Docker                 │    │
│  │  PostgreSQL │ Keycloak │ Backend │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │    Caddy (SSL) │ Frontend       │    │
│  └─────────────────────────────────┘    │
│              │                           │
│              ▼                           │
│  ┌─────────────────────────────────┐    │
│  │      Persistent Disk (20GB)      │    │
│  │         /data/postgres           │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Getting Started Workflow

After installation, follow these steps to set up your organization:

### 1. Sign in as Admin
Log in with `adminuser` / `adminuser` to access the admin panel.

### 2. Create a Group
Navigate to **Users & Groups** and create a new group (e.g., "RH").
A Knowledge Base is automatically created for each group.

### 3. Create Users
Create users and assign them to appropriate groups.

### 4. Grant Write Permissions
In **KB Management**, grant WRITE permission to users who need to manage documents.

### 5. Upload Documents
Users with WRITE permission can upload files via the **Knowledge Base** page using drag & drop.

### 6. Start Chatting
All group members can query the knowledge base through the chat interface.

## User Roles & Groups

### Roles

| Role | Description |
|------|-------------|
| `ADMIN` | Manage users, groups, KBs and permissions (no access to KB content) |
| `USER` | Access to chat and knowledge bases based on group membership |

### Default Setup

| User | Password | Role | Description |
|------|----------|------|-------------|
| `adminuser` | `adminuser` | ADMIN | Default administrator |

### Permission Model

| Permission | Description |
|------------|-------------|
| **READ** (implicit) | All group members can query the KB via chat |
| **WRITE** (explicit) | User can add/modify/delete documents in the KB |
| **READ cross-group** | User can read a KB they're not a member of |

**Key principle**: ADMIN role manages access but cannot read document content.

## File Upload

### Supported Formats

| Category | Extensions |
|----------|------------|
| **Documents** | `.pdf`, `.docx` |
| **Text** | `.txt`, `.md` |
| **Code** | `.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.c`, `.cpp`, `.h`, `.rs`, `.go`, `.java`, `.html`, `.css`, `.json`, `.yaml`, `.sql`, `.sh`, and more |

### Features

- Drag & drop upload interface
- Automatic text extraction from PDF and Word documents
- Column-aware PDF extraction for multi-column layouts
- Automatic chunking for large documents
- Language detection for code files
- Maximum file size: 200MB
- Metadata preservation (filename, type, language)
- Batch deletion of documents

## Multi-KB Architecture

The application supports multiple knowledge bases: group KBs linked to Keycloak groups, and personal KBs for individual users.

### How it works

**Group Knowledge Bases:**
1. ADMIN creates a group → Knowledge Base is auto-created
2. Group members automatically have READ access to their KB
3. ADMIN grants WRITE permission to specific users
4. Users with WRITE can upload documents (text or files)

**Personal Knowledge Bases:**
1. Auto-created when user first accesses the Knowledge Base page
2. Only the owner can access their personal KB
3. Configurable limits (default: 10 documents, 50MB total)
4. Marked with "Personal" badge in the UI

**Chat Integration:**
- Chat searches all accessible KBs (group + personal) and cites sources in responses

### Knowledge Base Management

**For Users (Knowledge Base page):**
- View all accessible KBs with READ/WRITE badges
- Personal KB shown with purple "Personal" badge
- Upload files via drag & drop (with WRITE permission)
- Add text documents manually
- Delete documents individually or in batch (with WRITE permission)

**For Admins (KB Management page):**
- View all group KBs with document counts
- Manage permissions (grant/revoke WRITE, add cross-group READ)
- Cannot access document content
- Personal KBs are not visible to admins

## Administration

### Users & Groups (`/admin/users`)

- Create and delete users
- Create and delete groups (auto-creates/deletes associated KB)
- Assign users to groups
- Toggle group membership

### KB Management (`/admin/knowledge-bases`)

- View all knowledge bases with document counts
- Grant WRITE permission to users
- Grant cross-group READ access
- Remove permissions

### Dashboard (`/admin`)

- System health monitoring
- Database connection status
- AI provider configuration
- Session statistics

## Multi-Conversations

Users can have multiple separate chat conversations, each with its own history.

### Features

- **Conversation List**: Sidebar displays recent conversations (10 most recent)
- **Auto-generated Titles**: Conversation title is automatically generated from the first message using AI
- **Full Management**: Create, rename, and delete conversations
- **Batch Deletion**: Delete multiple conversations at once via the management page (`/conversations`)
- **Persistent History**: Each conversation maintains its own chat history across sessions
- **History Display**: Previous messages are loaded and displayed when switching conversations

### How it works

1. User creates a new conversation (or one is auto-created)
2. Each conversation has a unique ID used as the CopilotKit `threadId`
3. First message triggers AI-powered title generation
4. Conversations are sorted by last activity (most recent first)
5. Switching conversations loads the appropriate chat history

## Session Memory

The agent remembers conversation history across page refreshes and server restarts.

1. User authenticates via Keycloak → receives a unique `user_id`
2. Each conversation has a unique `conversation_id` used as `threadId`
3. Backend (Agno) stores conversation history in PostgreSQL (`agent_sessions` table)
4. On each request, Agno loads the session history from the database

## RAG (Retrieval-Augmented Generation)

The agent searches accessible knowledge bases to answer questions with relevant context.

### How it works

1. Users upload documents via the Knowledge Base UI (group KBs require WRITE permission)
2. Content is extracted with smart processing:
   - **PDFs**: Column-aware extraction for multi-column documents (PyMuPDF + pdfplumber fallback)
   - **Large files**: Automatic chunking for documents up to 200MB
3. Text is chunked and embedded using OpenAI `text-embedding-3-small`
4. Embeddings are stored in PostgreSQL with PgVector
5. On each query, relevant documents are retrieved from all accessible KBs (group + personal)
6. The agent uses this context and **cites the source documents** in responses

### Knowledge Base Types

| Type | Access | Description |
|------|--------|-------------|
| **Group KB** | Group members | Shared KB for each Keycloak group |
| **Personal KB** | Owner only | Private KB for individual users |

### Requirements

RAG requires OpenAI API key for embeddings (even when using other providers for chat).

## Web Search

The agent can search the web for real-time information using DuckDuckGo.

- Automatically triggered when knowledge base doesn't have relevant information
- Useful for current events, recent updates, and general knowledge
- No API key required (uses DuckDuckGo's free search)

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
| `app.conversations` | User conversations metadata (title, timestamps) |
| `app.agent_sessions` | Session data and conversation runs (Agno) |
| `app.knowledge_bases` | KB metadata (name, slug, group, owner) |
| `app.knowledge_embeddings` | RAG document embeddings (PgVector) |
| `app.knowledge_base_permissions` | WRITE and cross-group READ permissions |

### Default Credentials (dev only)

| User | Password | Purpose |
|------|----------|---------|
| postgres | postgres | Superuser (never used in app) |
| migration | migration | Schema migrations (DDL) |
| appuser | appuser | Application runtime |
| keycloak | keycloak | Keycloak database access |

## Available Commands

### Setup Commands

| Command | Description |
|---------|-------------|
| `make setup-dev` | Configure local development environment |
| `make setup-staging` | Configure staging environment (cloud) |
| `make setup-deploy` | Configure production environment (cloud) |
| `make test-setup` | Run automated tests for setup commands |

### Docker Commands

| Command | Description |
|---------|-------------|
| `make dev-up` | Start backend services (PostgreSQL, Keycloak, Backend) |
| `make dev-down` | Stop all services |
| `make dev-logs` | Show container logs |
| `make dev-ps` | Show container status |
| `make dev-clean` | Remove all data and volumes |
| `make db-migrate` | Run database migrations |

### Frontend Commands

| Command | Description |
|---------|-------------|
| `make frontend` | Start frontend development server |
| `make frontend-install` | Install frontend dependencies |
| `make frontend-env` | Generate frontend/.env.local |

### Infrastructure Commands (Cloud)

| Command | Description |
|---------|-------------|
| `make infra-init` | Initialize OpenTofu |
| `make infra-plan` | Preview infrastructure changes |
| `make infra-apply` | Deploy infrastructure |
| `make infra-destroy` | Destroy infrastructure |
| `make infra-output` | Show infrastructure outputs |

## AI Providers

| Provider | Type | Configuration |
|----------|------|---------------|
| OpenAI | Cloud | `AI_PROVIDER=openai AI_API_KEY=sk-...` |
| Anthropic | Cloud | `AI_PROVIDER=anthropic AI_API_KEY=sk-ant-...` |
| Google Gemini | Cloud | `AI_PROVIDER=gemini AI_API_KEY=...` |
| Mistral | Cloud | `AI_PROVIDER=mistral AI_API_KEY=...` |
| Azure OpenAI | Cloud | `AI_PROVIDER=azure-openai AZURE_OPENAI_API_KEY=... AZURE_OPENAI_ENDPOINT=https://<resource>.openai.azure.com AZURE_OPENAI_DEPLOYMENT=<deployment-name>` |
| Azure AI Foundry | Cloud | `AI_PROVIDER=azure-ai-foundry AZURE_API_KEY=... AZURE_ENDPOINT=https://<resource>.models.ai.azure.com` |
| Ollama | Local | `AI_PROVIDER=ollama AI_URL=http://host.docker.internal:11434` |
| LM Studio | Local | `AI_PROVIDER=lmstudio AI_URL=http://host.docker.internal:1234` |

### Azure Providers

**Azure OpenAI** (`azure-openai`): Use this for GPT models (GPT-4o, GPT-5.2, etc.) deployed through Azure OpenAI Service or Azure AI Foundry with `cognitiveservices.azure.com` or `openai.azure.com` endpoints. Requires a deployment name.

**Azure AI Foundry** (`azure-ai-foundry`): Use this for serverless models (Phi-4, Llama, Mistral) deployed through Azure AI Foundry with `models.ai.azure.com` endpoints.

## Keycloak Admin Console

Access Keycloak admin at `http://localhost:8080` with:
- **Username:** `admin`
- **Password:** `admin`

## Renaming the Project

To rename the project for your own use (after forking):

```bash
./scripts/rename-project.sh "My Project Name"
```

This updates all references (containers, database, Keycloak realm, UI).

## Roadmap

- [x] Multi-provider AI support
- [x] Authentication (Keycloak + NextAuth.js)
- [x] Session Memory (PostgreSQL)
- [x] RAG (Retrieval-Augmented Generation with PgVector)
- [x] Multi-KB with group-based access control
- [x] File upload (PDF, Word, Markdown, Code files)
- [x] Modern UI with shadcn/ui
- [x] Dark/Light theme support
- [x] Admin dashboard (stats, health monitoring)
- [x] Admin user & group management
- [x] KB Management (permissions, WRITE/READ control)
- [x] Source citations in chat responses
- [x] Infrastructure as Code - AWS (OpenTofu)
- [x] Infrastructure as Code - Azure (OpenTofu)
- [x] Web search (DuckDuckGo integration)
- [x] Large file support (chunking up to 200MB)
- [x] Smart PDF extraction (column-aware for multi-column docs)
- [x] Personal Knowledge Bases (private per-user KBs)
- [x] Batch document deletion
- [x] Multi-conversations (multiple chats per user)
- [x] Auto-generated conversation titles (AI-powered)
- [x] Conversation history display (load previous messages)
- [ ] KB selector in chat (filter by specific KB)
- [ ] User Memory (persistent user preferences)
- [ ] Infrastructure as Code - GCP (OpenTofu)
- [ ] Infrastructure as Code - Scaleway (OpenTofu)
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
