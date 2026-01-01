#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== Starting Keystone setup $(date) ==="

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

# Install Caddy
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update
apt-get install -y caddy

# Install additional tools
apt-get install -y git make jq nvme-cli

# Format and mount PostgreSQL data volume
echo "=== Setting up PostgreSQL data volume ==="
DATA_DEVICE="/dev/nvme1n1"

while [ ! -e $DATA_DEVICE ]; do
  echo "Waiting for data volume..."
  sleep 5
done

if ! blkid $DATA_DEVICE; then
  echo "Formatting data volume..."
  mkfs.ext4 $DATA_DEVICE
fi

mkdir -p /data/postgres
mount $DATA_DEVICE /data/postgres

if ! grep -q "$DATA_DEVICE" /etc/fstab; then
  echo "$DATA_DEVICE /data/postgres ext4 defaults,nofail 0 2" >> /etc/fstab
fi

chown -R 999:999 /data/postgres

# Clone Keystone
echo "=== Cloning Keystone ==="
cd /opt
git clone https://github.com/fulltechfactory/keystone.git
cd keystone

# Create production config
cat > .deploy-config << 'DEPLOYCONFIG'
ENVIRONMENT=prod
CLOUD_PROVIDER=aws
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

# Create docker-compose override for production Keycloak
cat > docker-compose.override.yml << 'OVERRIDE'
services:
  keycloak:
    environment:
      KC_HOSTNAME: ${domain_name}
      KC_HOSTNAME_STRICT: "true"
      KC_PROXY_HEADERS: "xforwarded"
OVERRIDE

# Configure Caddy
cat > /etc/caddy/Caddyfile << 'CADDYFILE'
${domain_name} {
    # NextAuth
    handle /api/auth/* {
        reverse_proxy localhost:3000 {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Host {host}
        }
    }
    
    # CopilotKit (frontend route)
    handle /api/copilotkit/* {
        reverse_proxy localhost:3000
    }
    handle /api/copilotkit {
        reverse_proxy localhost:3000
    }
    
    # Backend API
    handle /api/* {
        reverse_proxy localhost:8000
    }

    # Keycloak
    handle /realms/* {
        reverse_proxy localhost:8080 {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-Host {host}
        }
    }
    handle /admin/* {
        reverse_proxy localhost:8080
    }
    handle /resources/* {
        reverse_proxy localhost:8080
    }

    # Frontend (default)
    reverse_proxy localhost:3000 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-Host {host}
    }
}
CADDYFILE

systemctl restart caddy

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

echo "=== Keystone setup complete $(date) ==="
echo "Application available at https://${domain_name}"
