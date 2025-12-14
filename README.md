# Agentic Fullstack Template

A fullstack template for building AI agentic applications with CopilotKit and Agno.

## Features

- **Multi-provider AI**: OpenAI, Anthropic, Google Gemini, Mistral, Ollama, LM Studio
- **Session Memory**: Conversation history persisted in PostgreSQL
- **Authentication**: Keycloak + NextAuth.js with secure OAuth2/OIDC
- **AG-UI Protocol**: Real-time streaming communication between frontend and backend
- **Multi-cloud ready**: Infrastructure as Code for AWS, GCP, Azure (OpenTofu)

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 16, React 19, TypeScript, CopilotKit |
| Backend | Python 3.11, Agno, FastAPI |
| Protocol | AG-UI (Agent-User Interaction) |
| Auth | Keycloak + NextAuth.js |
| Database | PostgreSQL 16 |
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
# For local development with Ollama
make setup-dev AI_PROVIDER=ollama AI_URL=http://host.docker.internal:11434

# Or with a cloud provider (OpenAI, Anthropic, etc.)
make setup-dev AI_PROVIDER=openai AI_API_KEY=sk-your-key
```

### 3. Start the backend services
```bash
make dev-up
```

This starts:
- PostgreSQL on `localhost:5432`
- Keycloak on `http://localhost:8080`
- Backend API on `http://localhost:8000`

Wait ~1 minute for Keycloak to initialize the realm and test user.

### 4. Start the frontend
```bash
make frontend
```

This will:
- Generate `frontend/.env.local` if needed
- Install dependencies if needed
- Start the Next.js development server

### 5. Access the application

Open `http://localhost:3000` and sign in with:
- **Username:** `testuser`
- **Password:** `testuser`

## Session Memory

The agent remembers conversation history across page refreshes and server restarts.

### How it works

1. User authenticates via Keycloak → receives a unique `user_id`
2. Frontend passes `user_id` as `threadId` to CopilotKit
3. Backend (Agno) stores conversation history in PostgreSQL
4. On each request, Agno loads the session history from the database

### Database tables (auto-created by Agno)

| Table | Purpose |
|-------|---------|
| `app.agent_sessions` | Session data and conversation runs |
| `app.agno_memories` | User memories (future) |
| `app.agno_knowledge` | Knowledge base (future) |

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

### Frontend Commands

| Command | Description |
|---------|-------------|
| `make frontend` | Start frontend development server |
| `make frontend-install` | Install frontend dependencies |
| `make frontend-env` | Generate frontend/.env.local |

## Project Structure
```
agentic-fullstack-template/
├── frontend/                   # Next.js + CopilotKit
│   ├── src/
│   │   ├── app/
│   │   │   ├── api/
│   │   │   │   ├── auth/       # NextAuth.js routes
│   │   │   │   └── copilotkit/ # AG-UI endpoint
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   └── providers.tsx
│   │   ├── auth.ts             # NextAuth configuration
│   │   └── types/              # TypeScript definitions
│   ├── Dockerfile
│   └── package.json
├── backend/                    # Python + Agno + FastAPI
│   ├── app/
│   │   ├── agents/             # Agent definitions
│   │   ├── config/             # Settings and model factory
│   │   └── main.py             # FastAPI application
│   ├── Dockerfile
│   └── requirements.txt
├── docker/                     # Docker initialization scripts
│   ├── keycloak/
│   │   └── setup-realm.sh      # Auto-configure realm, client, user
│   └── postgres/
│       └── init-db.sh          # Initialize schemas and users
├── infra/                      # OpenTofu configurations
│   ├── aws/
│   ├── gcp/
│   └── azure/
├── scripts/                    # Utility scripts
├── docker-compose.yml
├── Makefile
└── README.md
```

## AI Providers

The template supports multiple AI providers:

| Provider | Type | Configuration |
|----------|------|---------------|
| OpenAI | Cloud | `AI_PROVIDER=openai AI_API_KEY=sk-...` |
| Anthropic | Cloud | `AI_PROVIDER=anthropic AI_API_KEY=sk-ant-...` |
| Google Gemini | Cloud | `AI_PROVIDER=gemini AI_API_KEY=...` |
| Mistral | Cloud | `AI_PROVIDER=mistral AI_API_KEY=...` |
| Ollama | Local | `AI_PROVIDER=ollama AI_URL=http://host.docker.internal:11434` |
| LM Studio | Local | `AI_PROVIDER=lmstudio AI_URL=http://host.docker.internal:1234` |

## Authentication

The template uses Keycloak for authentication with NextAuth.js integration.

### Default Configuration (dev/staging)

| Setting | Value |
|---------|-------|
| Realm | `agentic` |
| Client ID | `agentic-app` |
| Client Secret | `agentic-secret` |
| Test User | `testuser` / `testuser` |

### Keycloak Admin Console

Access Keycloak admin at `http://localhost:8080` with:
- **Username:** `admin`
- **Password:** `admin`

## Database

### Default Credentials (dev/staging)

| User | Password | Purpose |
|------|----------|---------|
| postgres | postgres | Superuser (never used in app) |
| migration | migration | Schema migrations (DDL) |
| appuser | appuser | Application runtime (DML + DDL in dev) |
| keycloak | keycloak | Keycloak database access |

### Schema Architecture

The database uses separate schemas for isolation:
- `app` - Application data (sessions, memories, knowledge)
- `keycloak` - Authentication data

## Roadmap

- [x] Multi-provider AI support
- [x] Authentication (Keycloak + NextAuth.js)
- [x] Session Memory (PostgreSQL)
- [ ] RAG (Retrieval-Augmented Generation with PgVector)
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
