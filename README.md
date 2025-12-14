# Agentic Fullstack Template

A fullstack template for building AI agentic applications with CopilotKit and Agno.

## Features

- **Multi-provider AI**: OpenAI, Anthropic, Google Gemini, Mistral, Ollama, LM Studio
- **Session Memory**: Conversation history persisted in PostgreSQL
- **RAG (Retrieval-Augmented Generation)**: Knowledge base with PgVector embeddings
- **Role-based Access Control**: User, RAG Supervisor, Admin roles via Keycloak
- **Modern UI**: shadcn/ui components with dark/light theme support
- **Authentication**: Keycloak + NextAuth.js with secure OAuth2/OIDC
- **AG-UI Protocol**: Real-time streaming communication between frontend and backend
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
git clone git@github.com:fulltechfactory/agentic-fullstack-template.git
cd agentic-fullstack-template
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

## User Roles

The application implements role-based access control with three user levels:

| User | Password | Roles | Access |
|------|----------|-------|--------|
| `testuser` | `testuser` | USER | Chat only |
| `ragmanager` | `ragmanager` | USER, RAG_SUPERVISOR | Chat + Knowledge Base Management |
| `adminuser` | `adminuser` | USER, ADMIN | Full access (Chat + Knowledge Base + Admin) |

### Role Permissions

| Feature | USER | RAG_SUPERVISOR | ADMIN |
|---------|------|----------------|-------|
| Chat with AI | ✅ | ✅ | ✅ |
| Knowledge Base Management | ❌ | ✅ | ✅ |
| Administration | ❌ | ❌ | ✅ |

## Session Memory

The agent remembers conversation history across page refreshes and server restarts.

### How it works

1. User authenticates via Keycloak → receives a unique `user_id`
2. Frontend passes `user_id` as `threadId` to CopilotKit
3. Backend (Agno) stores conversation history in PostgreSQL
4. On each request, Agno loads the session history from the database

## RAG (Retrieval-Augmented Generation)

The agent can search a knowledge base to answer questions with relevant context.

### How it works

1. RAG Supervisors add documents via the Knowledge Base UI
2. Content is chunked and embedded using OpenAI `text-embedding-3-small`
3. Embeddings are stored in PostgreSQL with PgVector
4. On each query, relevant documents are retrieved and added to context
5. The agent uses this context to provide informed answers

### Knowledge API
```bash
# Add content to knowledge base
curl -X POST http://localhost:8000/api/knowledge/add \
  -H "Content-Type: application/json" \
  -d '{"content": "Your text content here", "name": "document_name"}'

# Search knowledge base
curl -X POST http://localhost:8000/api/knowledge/search \
  -H "Content-Type: application/json" \
  -d '{"query": "Your search query", "limit": 5}'
```

### Requirements

RAG requires OpenAI API key for embeddings (even when using other providers for chat).

## UI Features

### Theme Support

The application supports light, dark, and system themes. Toggle via the sun/moon icon in the sidebar footer.

### Responsive Sidebar

- Collapsible sidebar with icon-only mode
- Role-based navigation items
- User profile with sign-out option

## Database

### Tables (auto-created by Agno)

| Table | Purpose |
|-------|---------|
| `app.agent_sessions` | Session data and conversation runs |
| `app.knowledge_embeddings` | RAG document embeddings (PgVector) |
| `app.agno_memories` | User memories (future) |
| `app.agno_knowledge` | Knowledge metadata |

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
- [x] Role-based Access Control (USER, RAG_SUPERVISOR, ADMIN)
- [x] Modern UI with shadcn/ui
- [x] Dark/Light theme support
- [ ] Admin dashboard
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
docker logs agentic-postgres
docker logs agentic-keycloak
docker logs agentic-backend
docker logs agentic-keycloak-setup
```

### Reset all data
```bash
make dev-clean
make dev-up
```

## License

MIT
