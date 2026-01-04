# AWS Deployment Runbook - VM Attached Storage

## Deployment Type: vm-attached-storage

This deployment type creates a single EC2 instance running all Keystone services (PostgreSQL, Keycloak, Backend, Frontend) with an attached EBS volume for data persistence.

**Best suited for:**
- Small to medium deployments (< 100 concurrent users)
- Development/staging environments
- Cost-conscious production deployments
- Single-region deployments

**Estimated cost:** ~$33/month (eu-west-3)

---

## (i) Prerequisites

### AWS Resources (Manual Setup)

| Resource | Purpose | How to Create |
|----------|---------|---------------|
| **AWS Account** | Infrastructure hosting | [AWS Console](https://aws.amazon.com/) |
| **Elastic IP** | Static public IP | `aws ec2 allocate-address --domain vpc --region eu-west-3` |
| **S3 Bucket** | SSL certificate persistence | See below |
| **Domain Name** | Public access URL | Purchase via registrar, point A record to Elastic IP |

### Create S3 Bucket for SSL Certificates
```bash
# Create bucket (name must be globally unique)
aws s3 mb s3://your-caddy-certs-bucket --region eu-west-3

# Enable versioning (recommended)
aws s3api put-bucket-versioning \
  --bucket your-caddy-certs-bucket \
  --versioning-configuration Status=Enabled

# Block public access
aws s3api put-public-access-block \
  --bucket your-caddy-certs-bucket \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

> **Important:** Create the S3 bucket manually (outside Terraform) so certificates survive infrastructure destroy/recreate cycles.

### Local Tools Required

| Tool | Version | Installation |
|------|---------|--------------|
| **AWS CLI** | 2.x | `brew install awscli` or [AWS docs](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| **OpenTofu** | 1.6+ | `brew install opentofu` |
| **Git** | 2.x | `brew install git` |
| **Make** | 3.x+ | Pre-installed on macOS/Linux |

### AWS CLI Configuration
```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name: eu-west-3
# Default output format: json
```

### Required AWS Permissions

The IAM user/role needs permissions for:
- EC2 (instances, volumes, security groups, key pairs)
- VPC (VPCs, subnets, internet gateways, route tables)
- IAM (roles, instance profiles, policies)
- S3 (for certificate bucket access)
- SSM (for Session Manager access)

---

## (ii) Architecture

### Infrastructure Diagram
```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                          │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │              Public Subnet (10.0.1.0/24)                │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌─────────────────────────────────────────────────┐   │  │  │
│  │  │  │           EC2 Instance (t3.medium)              │   │  │  │
│  │  │  │                                                 │   │  │  │
│  │  │  │  ┌─────────────────────────────────────────┐   │   │  │  │
│  │  │  │  │              Docker                      │   │   │  │  │
│  │  │  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐   │   │   │  │  │
│  │  │  │  │  │PostgreSQL│ │Keycloak │ │ Backend │   │   │   │  │  │
│  │  │  │  │  │  :5432   │ │  :8080  │ │  :8000  │   │   │   │  │  │
│  │  │  │  │  └─────────┘ └─────────┘ └─────────┘   │   │   │  │  │
│  │  │  │  │  ┌─────────┐                           │   │   │  │  │
│  │  │  │  │  │Frontend │                           │   │   │  │  │
│  │  │  │  │  │  :3000  │                           │   │   │  │  │
│  │  │  │  │  └─────────┘                           │   │   │  │  │
│  │  │  │  └─────────────────────────────────────────┘   │   │  │  │
│  │  │  │                                                 │   │  │  │
│  │  │  │  ┌─────────────────────────────────────────┐   │   │  │  │
│  │  │  │  │    Caddy (Reverse Proxy + SSL)          │   │   │  │  │
│  │  │  │  │    :80, :443 → Backend/Keycloak/Frontend│   │   │  │  │
│  │  │  │  └─────────────────────────────────────────┘   │   │  │  │
│  │  │  └─────────────────────────────────────────────────┘   │  │  │
│  │  │           │                                             │  │  │
│  │  │           │ /dev/nvme1n1                               │  │  │
│  │  │           ▼                                             │  │  │
│  │  │  ┌─────────────────┐                                   │  │  │
│  │  │  │   EBS Volume    │                                   │  │  │
│  │  │  │   20GB gp3      │                                   │  │  │
│  │  │  │ /data/postgres/ │                                   │  │  │
│  │  │  └─────────────────┘                                   │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────┐    ┌────────────────┐    ┌─────────────────────┐   │
│  │ Elastic IP │    │ Security Group │    │    S3 Bucket        │   │
│  │ (static)   │    │ 80, 443 open   │    │ (SSL certificates)  │   │
│  └────────────┘    └────────────────┘    └─────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS :443
                              ▼
                     ┌─────────────────┐
                     │   Internet      │
                     │   Users         │
                     └─────────────────┘
```

### Components

| Component | Technology | Port | Purpose |
|-----------|------------|------|---------|
| **Reverse Proxy** | Caddy | 80, 443 | SSL termination, routing |
| **Frontend** | Next.js 15 | 3000 | Web UI |
| **Backend** | FastAPI + Agno | 8000 | AI agent, API |
| **Auth** | Keycloak | 8080 | OAuth2/OIDC |
| **Database** | PostgreSQL 16 + PgVector | 5432 | Data storage |

### Data Persistence

| Data | Location | Persistence |
|------|----------|-------------|
| PostgreSQL data | `/data/postgres/pgdata` (EBS) | Survives instance termination |
| SSL certificates | S3 bucket | Survives infrastructure destroy |
| Application code | `/opt/keystone` (root volume) | Rebuilt on deploy |
| Docker images | Root volume | Rebuilt on deploy |

### Network Flow
```
User Request → Elastic IP → Caddy (:443)
                              │
                              ├── /realms/* → Keycloak (:8080)
                              ├── /resources/* → Keycloak (:8080)
                              ├── /api/* → Backend (:8000)
                              ├── /agui/* → Backend (:8000)
                              └── /* → Frontend (:3000)
```

---

## (iii) Deploy From Scratch

### Step 1: Clone Repository
```bash
git clone git@github.com:fulltechfactory/keystone.git
cd keystone
```

### Step 2: Configure Production Environment
```bash
make setup-deploy
```

Answer the prompts:

| Prompt | Example Value | Notes |
|--------|---------------|-------|
| Cloud provider | `aws` | Only AWS supported currently |
| Infrastructure type | `vm-attached-storage` | Single VM deployment |
| Domain name | `www.example.com` | Must point to your Elastic IP |
| Existing Elastic IP? | `y` | Recommended |
| Elastic IP allocation ID | `eipalloc-xxx` | From AWS console |
| AI provider | `openai` | Required for RAG embeddings |
| AI API key | `sk-...` | Your OpenAI API key |
| Database passwords | (generate strong) | No `@`, `:`, `/`, `#` characters |
| Keystone admin password | (generate strong) | For adminuser login |
| Keycloak admin password | (generate strong) | For Keycloak console |
| Caddy S3 bucket name | `your-caddy-certs-bucket` | Created in prerequisites |

### Step 3: Initialize OpenTofu
```bash
make infra-init
```

### Step 4: Preview Infrastructure
```bash
make infra-plan
```

Review the plan. Expected resources:
- 1 VPC + subnet + internet gateway + route table
- 1 Security group (ports 80, 443)
- 1 IAM role + instance profile
- 1 EC2 instance (t3.medium)
- 1 EBS volume (20GB)
- 1 Elastic IP association

### Step 5: Deploy Infrastructure
```bash
make infra-apply
```

Deployment takes ~5-10 minutes.

### Step 6: Monitor Deployment
```bash
# Get instance ID
make infra-output

# Connect via SSM
aws ssm start-session --target <instance-id> --region eu-west-3

# Watch deployment logs
sudo tail -f /var/log/user-data.log
```

Wait for: `=== Keystone setup complete ===`

### Step 7: Verify Deployment
```bash
# On the server
sudo docker ps  # All 4 containers running
sudo systemctl status caddy  # Caddy active

# From your machine
curl -I https://your-domain.com  # Should return 200
```

### Step 8: Access Application

1. Open `https://your-domain.com`
2. Sign in with `adminuser` / `<your-keystone-admin-password>`
3. Create groups, users, and start using the application

---

## (iv) Update Procedures

### Update Backend Only
```bash
# Connect to server
aws ssm start-session --target <instance-id> --region eu-west-3

# Update
cd /opt/keystone
sudo git pull
sudo docker compose build --no-cache backend
sudo docker compose up -d backend

# Verify
sudo docker logs -f keystone-backend
```

### Update Frontend Only
```bash
# Connect to server
aws ssm start-session --target <instance-id> --region eu-west-3

# Update
cd /opt/keystone
sudo git pull
sudo docker compose build --no-cache frontend
sudo docker compose up -d frontend

# Verify
sudo docker logs -f keystone-frontend
```

### Update All Services
```bash
# Connect to server
aws ssm start-session --target <instance-id> --region eu-west-3

# Update
cd /opt/keystone
sudo git pull
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d

# Verify
sudo docker ps
sudo docker compose logs -f
```

### Update Infrastructure (OpenTofu)
```bash
# On local machine
cd keystone
git pull
make infra-plan  # Review changes
make infra-apply  # Apply changes
```

> **Warning:** Some infrastructure changes may cause downtime or data loss. Always review the plan carefully.

### Rollback Procedure
```bash
# Connect to server
aws ssm start-session --target <instance-id> --region eu-west-3

# Rollback to specific commit
cd /opt/keystone
sudo git fetch
sudo git checkout <commit-hash>
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d
```

---

## (v) Troubleshooting Runbook

### Quick Health Check
```bash
# Connect to server
aws ssm start-session --target <instance-id> --region eu-west-3

# Check all services
sudo docker ps
sudo systemctl status caddy
df -h /data/postgres  # EBS volume mounted?
curl -s http://localhost:8000/health | jq  # Backend healthy?
curl -s http://localhost:3000  # Frontend responding?
```

### Problem: Cannot Connect to Server

**Symptoms:** SSM session fails, SSH times out

**Investigation:**
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <instance-id> --region eu-west-3

# Check if instance is running
aws ec2 describe-instances --instance-ids <instance-id> --region eu-west-3 \
  --query 'Reservations[0].Instances[0].State.Name'
```

**Solutions:**
1. Instance stopped → Start via AWS console
2. Instance terminated → Run `make infra-apply` to recreate
3. SSM agent not running → Reboot instance via AWS console

### Problem: Website Not Loading (Connection Refused)

**Symptoms:** Browser shows "Connection refused" or timeout

**Investigation:**
```bash
# On server
sudo systemctl status caddy
sudo journalctl -u caddy -n 50
sudo docker ps
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Caddy not running | `sudo systemctl start caddy` |
| Caddy config error | Check `/etc/caddy/Caddyfile`, then `sudo systemctl restart caddy` |
| Security group | Verify ports 80, 443 are open in AWS console |
| Docker not running | `sudo systemctl start docker && cd /opt/keystone && sudo docker compose up -d` |

### Problem: SSL Certificate Error

**Symptoms:** Browser shows "Invalid certificate" or "Not secure"

**Investigation:**
```bash
sudo journalctl -u caddy -n 100 | grep -i "certificate\|acme\|tls"
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Rate limited (429) | Wait 1 week, certificates are cached in S3 |
| DNS not propagated | Verify A record: `dig +short your-domain.com` |
| S3 access denied | Check IAM role has S3 permissions |
| Wrong domain | Verify `domain_name` in `.deploy-config` |

### Problem: "Sign in with Keycloak" Error

**Symptoms:** Login redirects to error page

**Investigation:**
```bash
sudo docker logs keystone-keycloak 2>&1 | tail -50
sudo docker logs keystone-keycloak-setup 2>&1
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Keycloak not ready | Wait 1-2 minutes, check `sudo docker ps` |
| Redirect URI mismatch | Check Keycloak admin console → Clients → keystone-app → Valid Redirect URIs |
| Database connection | Check PostgreSQL: `sudo docker logs keystone-postgres` |

### Problem: Keycloak Cannot Connect to Database

**Symptoms:** `password authentication failed for user "keycloak"`

**Investigation:**
```bash
sudo docker logs keystone-keycloak 2>&1 | grep -i "password\|authentication\|database"
```

**Solutions:**
```bash
# Reset Keycloak password in PostgreSQL
source /opt/keystone/.deploy-config
sudo docker exec keystone-postgres psql -U postgres -c \
  "ALTER USER keycloak WITH PASSWORD '$DB_KEYCLOAK_PASSWORD';"
sudo docker compose restart keycloak
```

### Problem: RAG Not Working

**Symptoms:** Chat doesn't find documents, "No relevant information found"

**Investigation:**
```bash
# Check backend logs
sudo docker logs keystone-backend 2>&1 | grep -i "knowledge\|search\|error"

# Check if documents exist
sudo docker exec keystone-postgres psql -U postgres -d keystone_db -c \
  "SELECT COUNT(*) FROM app.knowledge_embeddings;"
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| No documents uploaded | Upload documents via Knowledge Base UI |
| OpenAI API key invalid | Check `.deploy-config`, restart backend |
| User not in group | Add user to group with documents |
| Missing permissions | Grant READ/WRITE permission in KB Management |

### Problem: PostgreSQL Data Lost

**Symptoms:** Users, groups, documents missing after restart

**Investigation:**
```bash
# Check EBS volume mounted
df -h /data/postgres
ls -la /data/postgres/pgdata/

# Check docker-compose override
cat /opt/keystone/docker-compose.override.yml | grep -A3 postgres
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| EBS not mounted | `sudo mount /dev/nvme1n1 /data/postgres` |
| Using Docker volume | Fix `docker-compose.override.yml` to use `/data/postgres/pgdata` |
| Data corrupted | Restore from backup (if available) |

### Problem: High Memory/CPU Usage

**Symptoms:** Application slow, instance unresponsive

**Investigation:**
```bash
htop  # or top
sudo docker stats
df -h  # Disk full?
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Memory exhausted | Upgrade to larger instance type |
| Disk full | Clean Docker: `sudo docker system prune -a` |
| Runaway process | `sudo docker compose restart` |

### Useful Commands Reference
```bash
# Service Management
sudo docker compose up -d          # Start all services
sudo docker compose down           # Stop all services
sudo docker compose restart        # Restart all services
sudo docker compose logs -f        # Follow all logs

# Individual Service Logs
sudo docker logs keystone-postgres
sudo docker logs keystone-keycloak
sudo docker logs keystone-backend
sudo docker logs keystone-frontend
sudo journalctl -u caddy -f

# Database Access
sudo docker exec -it keystone-postgres psql -U postgres -d keystone_db

# Check Configurations
cat /opt/keystone/.deploy-config
cat /opt/keystone/docker-compose.override.yml
cat /etc/caddy/Caddyfile

# Disk and Memory
df -h
free -m
sudo docker system df
```

---

## Appendix: File Locations

| File | Location | Purpose |
|------|----------|---------|
| Application code | `/opt/keystone/` | Git repository |
| Deploy config | `/opt/keystone/.deploy-config` | Environment variables |
| Docker override | `/opt/keystone/docker-compose.override.yml` | Production overrides |
| PostgreSQL data | `/data/postgres/pgdata/` | Database files (EBS) |
| Caddy config | `/etc/caddy/Caddyfile` | Reverse proxy config |
| Caddy binary | `/usr/bin/caddy` | Custom build with S3 |
| User-data log | `/var/log/user-data.log` | Deployment log |
| SSL certificates | S3 bucket | Managed by Caddy |

## Appendix: Port Reference

| Port | Service | Access |
|------|---------|--------|
| 22 | SSH | Disabled (use SSM) |
| 80 | Caddy HTTP | Public (redirects to 443) |
| 443 | Caddy HTTPS | Public |
| 3000 | Frontend | Internal only |
| 5432 | PostgreSQL | Internal only |
| 8000 | Backend | Internal only |
| 8080 | Keycloak | Internal only |
