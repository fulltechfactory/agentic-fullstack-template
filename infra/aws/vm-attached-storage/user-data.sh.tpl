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

mkdir -p /data/postgres/pgdata
chown -R 999:999 /data/postgres/pgdata

# Clone Keystone
echo "=== Cloning Keystone ==="
cd /opt
git clone https://github.com/fulltechfactory/agentic-fullstack-template.git keystone
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

# Install Caddy with S3 storage plugin
echo "=== Installing Caddy with S3 storage ==="
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https

# Install Go for xcaddy
wget -q https://go.dev/dl/go1.25.5.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz
rm go1.25.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/root/go
export GOCACHE=/root/.cache/go-build
export HOME=/root
export PATH=$PATH:$GOPATH/bin

# Install xcaddy and build Caddy with S3 module
go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
xcaddy build --with github.com/ss098/certmagic-s3

# Move custom caddy to system location
mv caddy /usr/bin/caddy
chmod +x /usr/bin/caddy

# Create caddy user and directories
useradd --system --home /var/lib/caddy --shell /usr/sbin/nologin caddy || true
mkdir -p /var/lib/caddy /etc/caddy
chown -R caddy:caddy /var/lib/caddy

# Create systemd service for caddy
cat > /etc/systemd/system/caddy.service << 'SYSTEMD'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
SYSTEMD

# Configure Caddy with S3 storage
cat > /etc/caddy/Caddyfile << 'CADDYFILE'
{
    storage s3 {
        host s3.${aws_region}.amazonaws.com
        bucket ${caddy_bucket_name}
        prefix "caddy"
        use_iam_provider true
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

systemctl daemon-reload
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

echo "=== Keystone setup complete $(date) ==="
echo "Application available at https://${domain_name}"
