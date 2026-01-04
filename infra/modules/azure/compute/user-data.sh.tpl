#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting Keystone setup on Azure $(date) ==="

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install Docker
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g pnpm

# Install additional tools
apt-get install -y git make jq

# Install Azure CLI for Blob Storage sync
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Format and mount PostgreSQL data volume
echo "=== Setting up PostgreSQL data volume ==="
DATA_DEVICE="/dev/sdc"

# Wait for data disk to be available
while [ ! -e $DATA_DEVICE ]; do
  echo "Waiting for data volume..."
  sleep 5
done

# Format if not already formatted
if ! blkid $DATA_DEVICE; then
  echo "Formatting data volume..."
  mkfs.ext4 $DATA_DEVICE
fi

# Mount data volume
mkdir -p /data/postgres
mount $DATA_DEVICE /data/postgres

# Add to fstab for persistence
if ! grep -q "$DATA_DEVICE" /etc/fstab; then
  echo "$DATA_DEVICE /data/postgres ext4 defaults,nofail 0 2" >> /etc/fstab
fi

# Create PostgreSQL data directory
mkdir -p /data/postgres/pgdata
chown -R 999:999 /data/postgres/pgdata

# Create Caddy data directory (on the persistent disk)
mkdir -p /data/caddy
chown -R root:root /data/caddy

# Clone Keystone
echo "=== Cloning Keystone ==="
cd /opt
git clone https://github.com/fulltechfactory/agentic-fullstack-template.git keystone
cd keystone

# Create production config
cat > .deploy-config << 'DEPLOYCONFIG'
ENVIRONMENT=prod
CLOUD_PROVIDER=azure
DOMAIN_NAME=${domain_name}

AI_PROVIDER=${ai_provider}
%{ if ai_provider == "openai" ~}
OPENAI_API_KEY=${ai_api_key}
%{ endif ~}
%{ if ai_provider == "anthropic" ~}
ANTHROPIC_API_KEY=${ai_api_key}
%{ endif ~}
%{ if ai_provider == "gemini" ~}
GOOGLE_API_KEY=${ai_api_key}
%{ endif ~}
%{ if ai_provider == "mistral" ~}
MISTRAL_API_KEY=${ai_api_key}
%{ endif ~}

POSTGRES_PASSWORD=${postgres_password}
DB_APP_HOST=postgres
DB_APP_PORT=5432
DB_APP_NAME=keystone_db
DB_APP_SCHEMA=app
DB_APP_USER=appuser
DB_APP_PASSWORD=${db_app_password}

DB_MIGRATION_USER=migration
DB_MIGRATION_PASSWORD=${db_migration_password}

DB_KEYCLOAK_HOST=postgres
DB_KEYCLOAK_PORT=5432
DB_KEYCLOAK_NAME=keystone_db
DB_KEYCLOAK_SCHEMA=keycloak
DB_KEYCLOAK_USER=keycloak
DB_KEYCLOAK_PASSWORD=${db_keycloak_password}

KEYSTONE_ADMIN=${keystone_admin}
KEYSTONE_ADMIN_PASSWORD=${keystone_admin_password}

KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=${keycloak_admin_password}
DEPLOYCONFIG

# Symlink for make commands
ln -s .deploy-config .dev-config

# Create docker-compose override for production
cat > docker-compose.override.yml << 'OVERRIDE'
services:
  postgres:
    volumes:
      - /data/postgres/pgdata:/var/lib/postgresql/data
      - ./docker/postgres/init-db.sh:/docker-entrypoint-initdb.d/init-db.sh:ro
  keycloak:
    environment:
      KC_HOSTNAME: ${domain_name}
      KC_HOSTNAME_STRICT: "true"
      KC_PROXY_HEADERS: "xforwarded"
OVERRIDE

# =============================================================================
# Caddy Certificate Sync with Azure Blob Storage
# =============================================================================
echo "=== Setting up Caddy certificate sync ==="

STORAGE_ACCOUNT="${storage_account_name}"
CONTAINER="${storage_container_name}"

# Create sync scripts
cat > /usr/local/bin/caddy-cert-download << 'SYNCDOWN'
#!/bin/bash
# Download certificates from Azure Blob Storage using Managed Identity
set -e
az login --identity --allow-no-subscriptions
if az storage blob list --account-name ${storage_account_name} --container-name ${storage_container_name} --auth-mode login --query "[].name" -o tsv | grep -q .; then
  echo "Downloading certificates from Azure Blob..."
  az storage blob download-batch \
    --account-name ${storage_account_name} \
    --source ${storage_container_name} \
    --destination /data/caddy \
    --auth-mode login \
    --overwrite true
  echo "Certificates downloaded successfully"
else
  echo "No certificates found in Azure Blob, starting fresh"
fi
SYNCDOWN

cat > /usr/local/bin/caddy-cert-upload << 'SYNCUP'
#!/bin/bash
# Upload certificates to Azure Blob Storage using Managed Identity
set -e
az login --identity --allow-no-subscriptions
if [ -d "/data/caddy" ] && [ "$(ls -A /data/caddy)" ]; then
  echo "Uploading certificates to Azure Blob..."
  az storage blob upload-batch \
    --account-name ${storage_account_name} \
    --destination ${storage_container_name} \
    --source /data/caddy \
    --auth-mode login \
    --overwrite true
  echo "Certificates uploaded successfully"
else
  echo "No certificates to upload"
fi
SYNCUP

chmod +x /usr/local/bin/caddy-cert-download
chmod +x /usr/local/bin/caddy-cert-upload

# Download existing certificates (if any)
/usr/local/bin/caddy-cert-download || echo "No existing certificates to download"

# Create cron job to sync certificates every hour
echo "0 * * * * root /usr/local/bin/caddy-cert-upload >> /var/log/caddy-sync.log 2>&1" > /etc/cron.d/caddy-cert-sync

# Create systemd service to sync on shutdown
cat > /etc/systemd/system/caddy-cert-sync.service << 'SYSTEMD'
[Unit]
Description=Sync Caddy certificates to Azure Blob
Before=shutdown.target reboot.target halt.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/local/bin/caddy-cert-upload
TimeoutStartSec=60

[Install]
WantedBy=halt.target reboot.target shutdown.target
SYSTEMD

systemctl daemon-reload
systemctl enable caddy-cert-sync

# =============================================================================
# Install Caddy (standard build, local storage)
# =============================================================================
echo "=== Installing Caddy ==="
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Create Caddy configuration
cat > /etc/caddy/Caddyfile << 'CADDYFILE'
{
    storage file_system {
        root /data/caddy
    }
}

${domain_name} {
    # Keycloak
    handle /realms/* {
        reverse_proxy localhost:8080 {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Host {host}
        }
    }
    handle /resources/* {
        reverse_proxy localhost:8080
    }

    # Everything else goes to frontend (including all /api/*)
    reverse_proxy localhost:3000 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
    }
}
CADDYFILE

# Ensure Caddy can write to storage
chown -R caddy:caddy /data/caddy

systemctl enable caddy
systemctl start caddy

# Start backend services
echo "=== Starting backend services ==="
make dev-up

# Wait for Keycloak to be ready
echo "=== Waiting for Keycloak ==="
sleep 30

# Update Keycloak client redirect URIs
docker exec keystone-keycloak /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password ${keycloak_admin_password}

CLIENT_ID=$(docker exec keystone-keycloak /opt/keycloak/bin/kcadm.sh get clients -r keystone -q clientId=keystone-app --fields id | grep -o '"id" : "[^"]*"' | cut -d'"' -f4)

docker exec keystone-keycloak /opt/keycloak/bin/kcadm.sh update clients/$CLIENT_ID \
    -r keystone \
    -s 'redirectUris=["https://${domain_name}/*", "http://localhost:3000/*"]' \
    -s 'webOrigins=["https://${domain_name}", "http://localhost:3000"]'

# Create frontend env
cat > frontend/.env.local << 'FRONTENDENV'
BACKEND_URL=http://localhost:8000
AUTH_SECRET=${auth_secret}
AUTH_TRUST_HOST=true
NEXTAUTH_URL=https://${domain_name}
KEYCLOAK_CLIENT_ID=keystone-app
KEYCLOAK_CLIENT_SECRET=keystone-secret
KEYCLOAK_ISSUER=https://${domain_name}/realms/keystone
FRONTENDENV

# Install frontend dependencies
cd frontend
pnpm install

# Create systemd service for frontend
cat > /etc/systemd/system/keystone-frontend.service << 'SYSTEMD'
[Unit]
Description=Keystone Frontend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/keystone/frontend
ExecStart=/usr/bin/pnpm start
Restart=on-failure
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SYSTEMD

# Build frontend for production
pnpm build --webpack

# Enable and start frontend service
systemctl daemon-reload
systemctl enable keystone-frontend
systemctl start keystone-frontend

# Upload initial certificates (after Caddy has obtained them)
sleep 60
/usr/local/bin/caddy-cert-upload || echo "Certificate upload will happen on next cron run"

echo "=== Keystone setup complete on Azure $(date) ==="
echo "Application available at https://${domain_name}"
