# Agentic Fullstack Template

A fullstack template for building AI agentic applications with CopilotKit and Agno.

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 16, React 19, TypeScript, CopilotKit |
| Backend | Python 3.11, Agno, FastAPI |
| Protocol | AG-UI (Agent-User Interaction) |
| Auth | Keycloak |
| Database | PostgreSQL 16 |
| Infrastructure | Docker, OpenTofu |

## Prerequisites

- **Node.js** 18+ (recommended: 20+)
- **pnpm** 9+ (install with `npm install -g pnpm`)
- **Python** 3.10+
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

### 4. Start the frontend
```bash
cd frontend
pnpm install
pnpm dev
```

Open `http://localhost:3000` in your browser.

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
| `make dev-up` | Start development environment |
| `make dev-down` | Stop development environment |
| `make dev-logs` | Show container logs |
| `make dev-ps` | Show container status |
| `make dev-clean` | Remove all data and volumes |

### Frontend Commands
```bash
cd frontend
pnpm dev      # Start development server
pnpm build    # Build for production
pnpm start    # Start production server
pnpm lint     # Run linter
```

## Project Structure
```
agentic-fullstack-template/
├── frontend/               # Next.js + CopilotKit
│   ├── src/
│   │   ├── app/
│   │   │   ├── api/copilotkit/  # AG-UI route
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   └── providers.tsx
│   │   └── ...
│   └── package.json
├── backend/                # Python + Agno + FastAPI
│   ├── app/
│   │   ├── agents/         # Agent definitions
│   │   ├── config/         # Settings and model factory
│   │   └── main.py         # FastAPI application
│   ├── Dockerfile
│   └── requirements.txt
├── docker/                 # Docker initialization scripts
│   ├── keycloak/
│   └── postgres/
├── infra/                  # OpenTofu configurations
│   ├── aws/
│   ├── gcp/
│   └── azure/
├── scripts/                # Utility scripts
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

## Environments

| Environment | Database | Keycloak | Credentials |
|-------------|----------|----------|-------------|
| dev | Docker (local) | Docker (local) | Default |
| staging | Docker (cloud VM) | Docker (cloud VM) | Default |
| prod | Docker (cloud VM) | Docker (cloud VM) | Manual |

## Default Credentials (dev/staging)

| Service | Username | Password |
|---------|----------|----------|
| Keycloak Admin | admin | admin |
| Keycloak Test User | testuser | testuser |
| PostgreSQL | postgres | postgres |
| App Database User | appuser | appuser |

## License

MIT
