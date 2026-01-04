# Azure Deployment Runbook - VM Attached Storage

## Deployment Type: vm-attached-storage

This deployment type creates a single Azure VM running all Keystone services (PostgreSQL, Keycloak, Backend, Frontend) with an attached Managed Disk for data persistence.

**Best suited for:**
- Small to medium deployments (< 100 concurrent users)
- Development/staging environments
- Cost-conscious production deployments
- Single-region deployments

**Estimated cost:** ~€35/month (francecentral, Standard_D2s_v3)

---

## (i) Prerequisites

### Azure Resources (Manual Setup - Permanent)

These resources must be created manually before deployment and will persist across infrastructure destroy/recreate cycles:

| Resource | Purpose | How to Create |
|----------|---------|---------------|
| **Azure Account** | Infrastructure hosting | [Azure Portal](https://portal.azure.com/) |
| **Resource Group** | Container for permanent resources | See below |
| **Public IP** | Static public IP | See below |
| **Storage Account** | SSL certificate persistence | See below |
| **Domain Name** | Public access URL | Purchase via registrar, point A record to Public IP |

### Create Permanent Resources

```bash
# Set variables
LOCATION="francecentral"
PERMANENT_RG="keystone-permanent-rg"
STORAGE_ACCOUNT="keystonecaddycerts"  # Must be globally unique, lowercase, no hyphens

# Create permanent resource group
az group create --name $PERMANENT_RG --location $LOCATION

# Create static public IP
az network public-ip create \
  --resource-group $PERMANENT_RG \
  --name keystone-public-ip \
  --sku Standard \
  --allocation-method Static \
  --location $LOCATION

# Get the IP address
az network public-ip show \
  --resource-group $PERMANENT_RG \
  --name keystone-public-ip \
  --query ipAddress -o tsv

# Create storage account for SSL certificates
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $PERMANENT_RG \
  --location $LOCATION \
  --sku Standard_LRS \
  --kind StorageV2

# Create container for Caddy certificates
az storage container create \
  --name caddy \
  --account-name $STORAGE_ACCOUNT
```

> **Important:** Create these resources manually (outside OpenTofu) so certificates and IP survive infrastructure destroy/recreate cycles.

### Configure DNS

Point your domain's A record to the Public IP address:
```
azure.example.com → <public-ip-address>
```

Verify DNS propagation:
```bash
dig +short azure.example.com
```

### Local Tools Required

| Tool | Version | Installation |
|------|---------|--------------|
| **Azure CLI** | 2.x | `brew install azure-cli` or [Azure docs](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) |
| **OpenTofu** | 1.6+ | `brew install opentofu` |
| **Git** | 2.x | `brew install git` |
| **Make** | 3.x+ | Pre-installed on macOS/Linux |

### Azure CLI Configuration
```bash
az login
az account show  # Verify subscription
```

### Required Azure Permissions

The user/service principal needs permissions for:
- Compute (Virtual Machines, Disks)
- Network (Virtual Networks, NICs, NSGs, Public IPs)
- Storage (Blob Storage read for permanent resources)
- Managed Identity (for VM to access Storage Account)

---

## (ii) Architecture

### Infrastructure Diagram
```
┌─────────────────────────────────────────────────────────────────────┐
│                         Azure Cloud                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Virtual Network (10.0.0.0/16)                    │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                 Subnet (10.0.1.0/24)                    │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌─────────────────────────────────────────────────┐   │  │  │
│  │  │  │         VM (Standard_D2s_v3)                    │   │  │  │
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
│  │  │           │ /dev/sdc                                   │  │  │
│  │  │           ▼                                             │  │  │
│  │  │  ┌─────────────────┐                                   │  │  │
│  │  │  │  Managed Disk   │                                   │  │  │
│  │  │  │  20GB StandardSSD│                                   │  │  │
│  │  │  │ /data/postgres/ │                                   │  │  │
│  │  │  └─────────────────┘                                   │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────┐    ┌────────────────┐    ┌─────────────────────┐   │
│  │ Public IP  │    │      NSG       │    │  Storage Account    │   │
│  │ (static)   │    │ 80, 443 open   │    │ (SSL certificates)  │   │
│  └────────────┘    └────────────────┘    └─────────────────────┘   │
│   (permanent)                              (permanent)              │
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
| PostgreSQL data | `/data/postgres/pgdata` (Managed Disk) | Survives VM deletion |
| SSL certificates | Azure Blob Storage | Survives infrastructure destroy |
| Application code | `/opt/keystone` (OS disk) | Rebuilt on deploy |
| Docker images | OS disk | Rebuilt on deploy |

### Network Flow
```
User Request → Public IP → Caddy (:443)
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
| Cloud provider | `azure` | Select option 3 |
| Infrastructure type | `vm-attached-storage` | Single VM deployment |
| Region | `francecentral` | Same as permanent resources |
| Domain name | `azure.example.com` | Must point to your Public IP |
| Azure Subscription ID | (auto-detected) | From `az account show` |
| Permanent Resource Group | `keystone-permanent-rg` | Created in prerequisites |
| Public IP name | `keystone-public-ip` | Created in prerequisites |
| Storage Account | `keystonecaddycerts` | Created in prerequisites |
| Storage Container | `caddy` | Created in prerequisites |
| AI provider | `openai` | Required for RAG embeddings |
| AI API key | `sk-...` | Your OpenAI API key |
| Database passwords | (generate strong) | No `@`, `:`, `/`, `#` characters |
| Keystone admin password | (generate strong) | For adminuser login |
| Keycloak admin password | (generate strong) | For Keycloak console |

### Step 3: Initialize OpenTofu
```bash
make infra-init
```

### Step 4: Preview Infrastructure
```bash
make infra-plan
```

Review the plan. Expected resources:
- 1 Resource Group (for infrastructure)
- 1 Virtual Network + Subnet
- 1 Network Security Group (ports 80, 443)
- 1 Network Interface
- 1 Managed Identity + Role Assignment
- 1 VM (Standard_D2s_v3)
- 1 Managed Disk (20GB)

### Step 5: Deploy Infrastructure
```bash
make infra-apply
```

Deployment takes ~5-10 minutes.

### Step 6: Monitor Deployment

```bash
# Get SSH key (if auto-generated)
cd infra/azure/vm-attached-storage
tofu output -raw generated_ssh_private_key > ~/.ssh/azure-keystone.pem
chmod 600 ~/.ssh/azure-keystone.pem

# Get public IP
tofu output public_ip

# Supprimer l'ancienne clé known_hosts
ssh-keygen -R [public_ip]

# Connect via SSH
ssh -i ~/.ssh/azure-keystone.pem azureuser@<public-ip>

# Watch deployment logs
sudo tail -f /var/log/user-data.log
```

Wait for: `=== Keystone setup complete on Azure ===`

### Step 7: Verify Deployment
```bash
# On the server
sudo docker ps  # All 3 containers running
sudo systemctl status keystone-frontend  # Frontend active
sudo systemctl status caddy  # Caddy active

# From your machine
curl -I https://your-domain.com  # Should return 200
```

### Step 8: Access Application

1. Open `https://your-domain.com`
2. Sign in with `adminuser` / `<your-keystone-admin-password>`
3. Create groups, users, and start using the application

---

## (iv) Common Operations

### Connect to Server

**Via SSH:**
```bash
ssh -i ~/.ssh/azure-keystone.pem azureuser@<public-ip>
```

**Via Azure Serial Console:**
1. Portal Azure → Virtual Machines → keystone-prod-vm
2. Help → Serial console
3. Login with `azureuser` (may need to reset password first)

### View Logs
```bash
# All Docker services
sudo docker compose -f /opt/keystone/docker-compose.yml logs -f

# Individual services
sudo docker logs keystone-backend -f
sudo docker logs keystone-keycloak -f
sudo docker logs keystone-postgres -f

# Frontend (systemd)
sudo journalctl -u keystone-frontend -f

# Caddy
sudo journalctl -u caddy -f

# Deployment log
sudo cat /var/log/user-data.log
```

### Restart Services
```bash
# All Docker services
cd /opt/keystone
sudo docker compose restart

# Frontend
sudo systemctl restart keystone-frontend

# Caddy
sudo systemctl restart caddy
```

### Update Application
```bash
# Connect to server
ssh -i ~/.ssh/azure-keystone.pem azureuser@<public-ip>

# Pull latest code and rebuild
cd /opt/keystone
sudo git pull
sudo docker compose build --no-cache
sudo docker compose up -d

# Rebuild frontend
cd frontend
sudo pnpm install
sudo pnpm build --webpack
sudo systemctl restart keystone-frontend
```

### Destroy Infrastructure
```bash
# From local machine
make infra-destroy
```

> **Note:** This destroys the VM and infrastructure Resource Group but preserves:
> - Public IP (in permanent Resource Group)
> - Storage Account with SSL certificates
> - DNS configuration

### Rollback Procedure
```bash
# Connect to server
ssh -i ~/.ssh/azure-keystone.pem azureuser@<public-ip>

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
ssh -i ~/.ssh/azure-keystone.pem azureuser@<public-ip>

# Check all services
sudo docker ps
sudo systemctl status keystone-frontend
sudo systemctl status caddy
df -h /data/postgres  # Managed Disk mounted?
curl -s http://localhost:8000/health | jq  # Backend healthy?
curl -s http://localhost:3000  # Frontend responding?
```

### Problem: Cannot Connect to Server

**Symptoms:** SSH times out, connection refused

**Investigation:**
```bash
# Check VM status
az vm show --resource-group keystone-prod-rg --name keystone-prod-vm --query powerState

# Check NSG rules
az network nsg rule list --resource-group keystone-prod-rg --nsg-name keystone-prod-nsg -o table
```

**Solutions:**
1. VM stopped → Start via Azure portal or `az vm start`
2. VM not found → Run `make infra-apply` to recreate
3. SSH port blocked → Add NSG rule for port 22 (see below)

**Add SSH rule (if needed):**
```bash
az network nsg rule create \
  --resource-group keystone-prod-rg \
  --nsg-name keystone-prod-nsg \
  --name AllowSSH \
  --priority 100 \
  --source-address-prefixes '<your-ip>/32' \
  --destination-port-ranges 22 \
  --protocol Tcp
```

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
| NSG blocking ports | Verify ports 80, 443 are open in Azure portal |
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
| Rate limited (429) | Wait 1 week, certificates are cached in Azure Blob |
| DNS not propagated | Verify A record: `dig +short your-domain.com` |
| Blob access denied | Check VM Managed Identity has Storage Blob Data Contributor role |
| Wrong domain | Verify `domain_name` in `.deploy-config` |

**Force certificate renewal:**
```bash
sudo systemctl stop caddy
sudo rm -rf /data/caddy/certificates
sudo /usr/local/bin/caddy-cert-download  # Download from Blob if exists
sudo systemctl start caddy
```

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

### Problem: Frontend Build Failed (Turbopack Error)

**Symptoms:** Frontend not starting, Turbopack errors in logs

**Investigation:**
```bash
sudo journalctl -u keystone-frontend -n 100
cat /var/log/user-data.log | grep -i "build\|error"
```

**Solution:**
```bash
cd /opt/keystone/frontend
sudo pnpm build --webpack  # Use webpack instead of turbopack
sudo systemctl restart keystone-frontend
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
# Check Managed Disk mounted
df -h /data/postgres
ls -la /data/postgres/pgdata/

# Check docker-compose override
cat /opt/keystone/docker-compose.override.yml | grep -A3 postgres
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Disk not mounted | `sudo mount /dev/sdc /data/postgres` |
| Using Docker volume | Fix `docker-compose.override.yml` to use `/data/postgres/pgdata` |
| Data corrupted | Restore from backup (if available) |

### Problem: High Memory/CPU Usage

**Symptoms:** Application slow, VM unresponsive

**Investigation:**
```bash
htop  # or top
sudo docker stats
df -h  # Disk full?
```

**Solutions:**

| Cause | Solution |
|-------|----------|
| Memory exhausted | Upgrade to larger VM size |
| Disk full | Clean Docker: `sudo docker system prune -a` |
| Runaway process | `sudo docker compose restart` |

### Useful Commands Reference
```bash
# Service Management
sudo docker compose up -d          # Start all Docker services
sudo docker compose down           # Stop all Docker services
sudo docker compose restart        # Restart all Docker services
sudo docker compose logs -f        # Follow all logs

# Individual Service Logs
sudo docker logs keystone-postgres
sudo docker logs keystone-keycloak
sudo docker logs keystone-backend
sudo journalctl -u keystone-frontend -f
sudo journalctl -u caddy -f

# Database Access
sudo docker exec -it keystone-postgres psql -U postgres -d keystone_db

# Check Configurations
cat /opt/keystone/.deploy-config
cat /opt/keystone/docker-compose.override.yml
cat /etc/caddy/Caddyfile

# Certificate Management
sudo /usr/local/bin/caddy-cert-upload    # Upload certs to Blob
sudo /usr/local/bin/caddy-cert-download  # Download certs from Blob

# Disk and Memory
df -h
free -m
sudo docker system df

# Azure CLI from VM (using Managed Identity)
az login --identity
az storage blob list --account-name keystonecaddycerts --container-name caddy --auth-mode login
```

---

## Appendix: File Locations

| File | Location | Purpose |
|------|----------|---------|
| Application code | `/opt/keystone/` | Git repository |
| Deploy config | `/opt/keystone/.deploy-config` | Environment variables |
| Docker override | `/opt/keystone/docker-compose.override.yml` | Production overrides |
| PostgreSQL data | `/data/postgres/pgdata/` | Database files (Managed Disk) |
| Caddy config | `/etc/caddy/Caddyfile` | Reverse proxy config |
| Caddy data | `/data/caddy/` | Certificates (local cache) |
| Cert upload script | `/usr/local/bin/caddy-cert-upload` | Sync certs to Blob |
| Cert download script | `/usr/local/bin/caddy-cert-download` | Sync certs from Blob |
| User-data log | `/var/log/user-data.log` | Deployment log |
| SSL certificates | Azure Blob Storage | Managed by sync scripts |

## Appendix: Port Reference

| Port | Service | Access |
|------|---------|--------|
| 22 | SSH | Optional (add NSG rule) |
| 80 | Caddy HTTP | Public (redirects to 443) |
| 443 | Caddy HTTPS | Public |
| 3000 | Frontend | Internal only |
| 5432 | PostgreSQL | Internal only |
| 8000 | Backend | Internal only |
| 8080 | Keycloak | Internal only |

## Appendix: Azure Resource Mapping

| AWS Equivalent | Azure Resource | Notes |
|----------------|----------------|-------|
| VPC | Virtual Network | 10.0.0.0/16 |
| Subnet | Subnet | 10.0.1.0/24 |
| Security Group | Network Security Group (NSG) | |
| Elastic IP | Public IP (Static) | In permanent RG |
| EC2 Instance | Virtual Machine | Standard_D2s_v3 |
| EBS Volume | Managed Disk | StandardSSD, 20GB |
| IAM Role | Managed Identity | System-assigned |
| S3 Bucket | Storage Account + Container | In permanent RG |
| SSM Session Manager | SSH + Serial Console | |
