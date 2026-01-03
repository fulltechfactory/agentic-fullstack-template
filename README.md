# Keystone

A fullstack template for building AI-powered applications with CopilotKit and Agno.

## Features

- **Multi-provider AI**: OpenAI, Anthropic, Google Gemini, Mistral, Ollama, LM Studio
- **Session Memory**: Conversation history persisted in PostgreSQL
- **Multi-KB RAG**: Multiple knowledge bases with group-based access control
- **File Upload**: Support for PDF, Word, Markdown, Text, and 20+ code file formats
- **Group-based Access Control**: Keycloak groups with READ/WRITE permissions per KB
- **Admin Dashboard**: User & group management, KB permissions, system health
- **Modern UI**: shadcn/ui components with dark/light theme support
- **Authentication**: Keycloak + NextAuth.js with secure OAuth2/OIDC
- **AG-UI Protocol**: Real-time streaming communication between frontend and backend
- **Source Citations**: AI responses cite document sources from knowledge base
- **Production Ready**: Infrastructure as Code with OpenTofu for AWS (GCP, Azure coming soon)

## Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 15, React 19, TypeScript, CopilotKit, shadcn/ui |
| Backend | Python 3.11, Agno, FastAPI |
| Protocol | AG-UI (Agent-User Interaction) |
| Auth | Keycloak + NextAuth.js |
| Database | PostgreSQL 16 + PgVector |
| Infrastructure | Docker, OpenTofu, Caddy |

## Prerequisites

### For Local Development

- **Node.js** 18+ (recommended: 20+)
- **pnpm** 9+ (install with `npm install -g pnpm`)
- **Docker** and Docker Compose
- **Git**

### For Production Deployment (AWS)

- **AWS CLI** configured with appropriate permissions
- **AWS Account** with EC2, VPC, EBS, S3, IAM access
- **Elastic IP** (recommended to allocate beforehand)
- **Domain name** pointing to your Elastic IP
- **S3 bucket** for SSL certificate persistence (created manually)
- **OpenTofu** 1.6+ (or Terraform)

### Optional (for local AI)

- **Ollama** for local LLM inference (https://ollama.ai)

## Quick Start (Local Development)

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

## Production Deployment (AWS)

### Architecture

The `vm-attached-storage` deployment creates:
- **VPC** with public subnet, internet gateway, route table
- **EC2 instance** (t3.medium) running all services
- **EBS volume** (20GB) for PostgreSQL data persistence
- **Elastic IP** for static public IP
- **Security Group** allowing ports 80, 443
- **IAM Role** for SSM access and S3 certificate storage
- **Caddy** reverse proxy with automatic Let's Encrypt SSL

### Prerequisites

1. **Create S3 bucket** for SSL certificates (survives infrastructure destroy):
```bash
aws s3 mb s3://your-caddy-certs-bucket --region eu-west-3
aws s3api put-bucket-versioning --bucket your-caddy-certs-bucket --versioning-configuration Status=Enabled
```

2. **Allocate Elastic IP** (optional but recommended):
```bash
aws ec2 allocate-address --domain vpc --region eu-west-3
```

3. **Configure DNS** to point your domain to the Elastic IP.

### Deployment Steps

#### 1. Configure production environment
```bash
make setup-deploy
```

Follow the prompts to configure:
- Cloud provider (AWS)
- Infrastructure type (vm-attached-storage)
- Domain name
- Elastic IP
- AI provider and API key
- Database passwords
- Admin credentials
- S3 bucket for certificates

#### 2. Initialize OpenTofu
```bash
make infra-init
```

#### 3. Preview infrastructure changes
```bash
make infra-plan
```

#### 4. Deploy infrastructure
```bash
make infra-apply
```

#### 5. Monitor deployment progress
```bash
# Get instance ID
make infra-output

# Connect via SSM
aws ssm start-session --target <instance-id> --region eu-west-3

# Watch deployment logs
sudo tail -f /var/log/user-data.log
```

#### 6. Access the application

Once deployment completes (~5-10 minutes), access your application at `https://your-domain.com`.

### Infrastructure Commands

| Command | Description |
|---------|-------------|
| `make infra-init` | Initialize OpenTofu (download providers) |
| `make infra-plan` | Preview infrastructure changes |
| `make infra-apply` | Create/update infrastructure |
| `make infra-destroy` | Destroy infrastructure (keeps S3 bucket) |
| `make infra-output` | Show infrastructure outputs (IPs, IDs) |

### SSL Certificates

- Certificates are automatically obtained from Let's Encrypt
- Stored in S3 bucket (persists across infrastructure destroy/recreate)
- Automatic renewal ~30 days before expiration
- Rate limit: 5 certificates per domain per week

### Cost Estimate (AWS eu-west-3)

| Resource | Monthly Cost |
|----------|-------------|
| EC2 t3.medium | ~$30 |
| EBS 20GB gp3 | ~$2 |
| Elastic IP | Free (if attached) |
| S3 (certificates) | <$1 |
| **Total** | **~$33/month** |

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
- Language detection for code files
- Maximum file size: 10MB
- Metadata preservation (filename, type, language)

## Multi-KB Architecture

The application supports multiple knowledge bases, each linked to a Keycloak group.

### How it works

1. ADMIN creates a group → Knowledge Base is auto-created
2. Group members automatically have READ access to their KB
3. ADMIN grants WRITE permission to specific users
4. Users with WRITE can upload documents (text or files)
5. Chat searches only accessible KBs and cites sources in responses

### Knowledge Base Management

**For Users (Knowledge Base page):**
- View all accessible KBs with READ/WRITE badges
- Upload files via drag & drop (with WRITE permission)
- Add text documents manually
- Delete documents (with WRITE permission)

**For Admins (KB Management page):**
- View all KBs with document counts
- Manage permissions (grant/revoke WRITE, add cross-group READ)
- Cannot access document content

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

## Session Memory

The agent remembers conversation history across page refreshes and server restarts.

1. User authenticates via Keycloak → receives a unique `user_id`
2. Frontend passes `user_id` as `threadId` to CopilotKit
3. Backend (Agno) stores conversation history in PostgreSQL
4. On each request, Agno loads the session history from the database

## RAG (Retrieval-Augmented Generation)

The agent searches accessible knowledge bases to answer questions with relevant context.

1. Users with WRITE permission upload documents via the Knowledge Base UI
2. Content is chunked and embedded using OpenAI `text-embedding-3-small`
3. Embeddings are stored in PostgreSQL with PgVector
4. On each query, relevant documents are retrieved from accessible KBs only
5. The agent uses this context and **cites the source documents** in responses

### Security

- RAG queries are filtered by user's group membership and explicit permissions
- Users can only access documents from KBs they have READ access to
- Cross-group access requires explicit permission from ADMIN

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

### Tables

| Table | Purpose |
|-------|---------|
| `app.agent_sessions` | Session data and conversation runs |
| `app.knowledge_bases` | KB metadata (name, slug, group) |
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

### Infrastructure Commands

| Command | Description |
|---------|-------------|
| `make infra-init` | Initialize OpenTofu providers |
| `make infra-plan` | Preview infrastructure changes |
| `make infra-apply` | Deploy infrastructure |
| `make infra-destroy` | Destroy infrastructure |
| `make infra-output` | Show outputs (IPs, instance ID) |

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
- [x] Infrastructure as Code - AWS (vm-attached-storage)
- [ ] KB selector in chat (filter by specific KB)
- [ ] User Memory (persistent user preferences)
- [ ] Infrastructure as Code - GCP
- [ ] Infrastructure as Code - Azure
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

### SSL Certificate Rate Limit

If you see `HTTP 429 rateLimited` errors from Let's Encrypt:
- Wait 1 week (limit: 5 certs per domain per week)
- Certificates persist in S3, so destroy/recreate won't request new ones
- Use staging environment for testing: modify Caddyfile to use `acme_ca https://acme-staging-v02.api.letsencrypt.org/directory`

### Production Deployment Issues
```bash
# Connect to instance
aws ssm start-session --target <instance-id> --region eu-west-3

# Check deployment logs
sudo tail -100 /var/log/user-data.log

# Check service status
docker ps
sudo systemctl status caddy

# Check Caddy logs
sudo journalctl -u caddy -f
```

## License

MIT
