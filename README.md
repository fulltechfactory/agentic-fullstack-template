# Agentic Fullstack Template

A fullstack template for building AI agentic applications with CopilotKit and Agno.

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js, React, TypeScript, CopilotKit |
| Backend | Python, Agno, FastAPI |
| Protocol | AG-UI (Agent-User Interaction) |
| Infrastructure | OpenTofu, Docker |

## Project Structure
```
agentic-fullstack-template/
├── frontend/           # Next.js + CopilotKit
├── backend/            # Python + Agno
├── infra/              # OpenTofu configurations
│   ├── aws/
│   ├── gcp/
│   └── azure/
├── docker-compose.yml  # Local orchestration
├── Makefile            # Project commands
└── README.md
```

## Environments

| Environment | Compute | Database | Data Persistence |
|-------------|---------|----------|------------------|
| dev | Local Docker | Postgres (Docker) | Docker volume |
| staging | Cloud VM | Postgres (Docker) | Docker volume |
| prod | Cloud VM | Postgres (Docker) | Attached disk |

## Prerequisites

- Node.js 18+
- Python 3.10+
- pnpm (recommended) or npm
- Docker & Docker Compose
- OpenTofu (for cloud deployment)

## Getting Started
```bash
# Setup cloud provider for deployment
make setup-deploy
```

## License

MIT
