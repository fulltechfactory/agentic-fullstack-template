# Keycloak Administration Guide

This document describes how to access the Keycloak admin console for each deployment platform.

---

## Overview

Keycloak is the identity and access management solution used by Keystone. The admin console allows you to:

- Manage users and groups
- Configure authentication flows
- View active sessions
- Manage client applications
- Configure realm settings

**Default Credentials:**
- **Username:** `admin`
- **Password:** Defined during setup (`KEYCLOAK_ADMIN_PASSWORD`)

---

## Local Development

### Access URL
```
http://localhost:8080/admin
```

### Credentials

- **Username:** `admin`
- **Password:** `admin` (default for dev)

### Steps

1. Start the development environment:
```bash
   make dev-up
```

2. Wait ~1 minute for Keycloak to initialize

3. Open `http://localhost:8080/admin` in your browser

4. Select realm **keystone** from the dropdown (top-left)

---

## AWS (vm-attached-storage)

### Why Not Publicly Accessible?

In production, the Keycloak admin console is **not exposed publicly** for security reasons. Only authentication endpoints are routed:

| Path | Routed | Purpose |
|------|--------|---------|
| `/realms/*` | ✅ Yes | User authentication |
| `/resources/*` | ✅ Yes | Static assets |
| `/admin/*` | ❌ No | Admin console |
| `/js/*` | ❌ No | Admin assets |

### Access via SSM Port Forwarding

**Prerequisites:**
- AWS CLI configured
- Session Manager plugin installed (`brew install session-manager-plugin` on macOS)

**Step 1: Get your instance ID**
```bash
cd keystone
make infra-output
# Note the instance_id value
```

**Step 2: Create SSH tunnel**
```bash
aws ssm start-session \
  --target <instance-id> \
  --region eu-west-3 \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
```

Keep this terminal open.

**Step 3: Access Keycloak**

Open in browser: `http://localhost:8080/admin`

**Step 4: Login**

- **Username:** `admin`
- **Password:** Your `KEYCLOAK_ADMIN_PASSWORD` from `make setup-deploy`

> **Tip:** Find your password in `.deploy-config` or `terraform.tfvars` (keep these files secure!)

### Alternative: Direct Server Access
```bash
# Connect to server
aws ssm start-session --target <instance-id> --region eu-west-3

# Use curl to interact with Keycloak API
curl -s http://localhost:8080/health/ready
```

---

## GCP (Coming Soon)

Documentation will be added when GCP deployment is implemented.

Access method will likely use:
- **IAP (Identity-Aware Proxy) tunnel**, or
- **gcloud compute ssh --tunnel-through-iap**

---

## Azure (Coming Soon)

Documentation will be added when Azure deployment is implemented.

Access method will likely use:
- **Azure Bastion**, or
- **az network bastion tunnel**

---

## Common Administration Tasks

### View All Users

1. Select realm: **keystone**
2. Navigate to: **Users** (left menu)
3. Click **View all users**

### Create a New User

1. Navigate to: **Users** → **Add user**
2. Fill in:
   - Username (required)
   - Email
   - First name / Last name
3. Click **Create**
4. Go to **Credentials** tab → **Set password**
5. Go to **Groups** tab → **Join group**

### View All Groups

1. Select realm: **keystone**
2. Navigate to: **Groups** (left menu)

### Create a New Group

> **Note:** In Keystone, groups should be created via the Admin UI (`/admin/users`), which automatically creates the associated Knowledge Base.

If you must create directly in Keycloak:

1. Navigate to: **Groups** → **Create group**
2. Name format: Use the group name (e.g., `RH`, `Finance`)

### View Active Sessions

1. Navigate to: **Sessions** (left menu)
2. View all active user sessions
3. Click **Logout all** to force all users to re-authenticate

### Check Client Configuration

1. Navigate to: **Clients** (left menu)
2. Click **keystone-app**
3. Important settings:
   - **Valid redirect URIs**: Must include your domain
   - **Web origins**: Must include your domain
   - **Client authentication**: ON

### View Realm Settings

1. Navigate to: **Realm settings** (left menu)
2. Tabs:
   - **General**: Realm name, display name
   - **Login**: Login page settings
   - **Tokens**: Token lifespans
   - **Sessions**: Session timeouts

---

## Troubleshooting

### "Invalid username or password" on Admin Console

**Cause:** Wrong credentials or Keycloak not fully initialized

**Solutions:**
1. Verify password in `.deploy-config` or `terraform.tfvars`
2. Wait 1-2 minutes for Keycloak to fully start
3. Check Keycloak logs:
```bash
   # Local
   docker logs keystone-keycloak
   
   # AWS (via SSM)
   sudo docker logs keystone-keycloak
```

### Port 8080 Already in Use (Local)

**Cause:** Another service using port 8080

**Solutions:**
```bash
# Find what's using the port
lsof -i :8080

# Stop the conflicting service, or change Keycloak port in docker-compose.yml
```

### SSM Port Forwarding Fails

**Cause:** Missing plugin or permissions

**Solutions:**
```bash
# Install Session Manager plugin (macOS)
brew install session-manager-plugin

# Verify AWS credentials
aws sts get-caller-identity

# Check instance is running
aws ec2 describe-instance-status --instance-ids <instance-id> --region eu-west-3
```

### Cannot See Realm "keystone"

**Cause:** Realm not created or Keycloak setup failed

**Solutions:**
1. Check if setup completed:
```bash
   # Local
   docker logs keystone-keycloak-setup
   
   # AWS
   sudo docker logs keystone-keycloak-setup
```

2. Re-run setup:
```bash
   # Local
   docker compose restart keycloak-setup
   
   # AWS
   sudo docker compose restart keycloak-setup
```

---

## Security Best Practices

1. **Never expose Keycloak admin publicly** - Always use tunneling
2. **Use strong admin password** - At least 16 characters
3. **Regularly rotate admin password** - Update via Keycloak console
4. **Monitor active sessions** - Check for suspicious activity
5. **Keep Keycloak updated** - Update Docker image regularly
6. **Enable audit logging** - For compliance requirements
