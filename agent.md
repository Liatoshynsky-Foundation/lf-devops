# Project Documentation

This document describes the Liatoshynsky Foundation DevOps infrastructure project, its structure, and how to work with it.

## Overview

This repository contains the DevOps infrastructure for the Liatoshynsky Foundation web services. It manages deployment and configuration of multiple services using Docker Compose, with Traefik as a reverse proxy and SSL termination.

## Project Structure

```
lf-devops/
├── compose.yaml          # Docker Compose configuration
├── traefik.yaml          # Traefik reverse proxy configuration
├── Makefile              # Convenience commands for project management
├── agent.md              # This documentation file
├── scripts/              # Utility scripts
│   ├── env-crypto.sh     # Common encryption/decryption functions
│   ├── encrypt-env.sh    # Encrypt .env files
│   ├── decrypt-env.sh    # Decrypt .env files
│   ├── edit-env.sh       # Edit encrypted .env files
│   └── check-env-secrets.sh  # Verify all secrets are encrypted
```

## Services

The infrastructure consists of the following services:

### 1. Traefik (Reverse Proxy)
- **Container**: `traefik`
- **Ports**: 80, 443
- **Purpose**: Reverse proxy with SSL/TLS termination
- **Configuration**: `traefik.yaml`
- **SSL**: Automatic certificate management via DNS-01 challenge with Cloudflare
- **Domains**:
  - `liatoshynsky.com` → lf-placeholder
  - `client.liatoshynsky.com` → lf-client (with basic auth)
  - `admin.liatoshynsky.com` → lf-admin (with basic auth)
  - `status.liatoshynsky.com` → uptime-kuma

### 2. lf-placeholder
- **Container**: `lf-placeholder`
- **Image**: `ghcr.io/liatoshynsky-foundation/lf-placeholder:latest`
- **Port**: 80 (internal)
- **Purpose**: Placeholder/main website
- **Environment**: `.env`

### 3. lf-client
- **Container**: `lf-client`
- **Image**: `ghcr.io/liatoshynsky-foundation/lf-client:1bcf6cb50f0c5f8f731c382a53524c3c771c645a`
- **Port**: 3000 (internal)
- **Purpose**: Client-facing application
- **Environment**: `.env.client`
- **Access**: Protected with basic authentication

### 4. lf-admin
- **Container**: `lf-admin`
- **Image**: `ghcr.io/liatoshynsky-foundation/lf-admin:8f9a9eb5ef759d653c558c40ad6a7bcd6f83f12d`
- **Port**: 3001 (internal)
- **Purpose**: Admin panel
- **Environment**: `.env.admin`
- **Access**: Protected with basic authentication

### 5. uptime-kuma
- **Container**: `uptime-kuma`
- **Image**: `louislam/uptime-kuma:2`
- **Port**: 4173 (internal)
- **Purpose**: Uptime monitoring and status page
- **Access**: Public (via status.liatoshynsky.com)

## Environment Files

The project uses encrypted environment files for secure secret management:

- `.env` - Main environment variables (used by lf-placeholder)
- `.env.traefik` - Traefik reverse proxy environment variables (Cloudflare credentials, basic auth hash)
- `.env.client` - Client application environment variables
- `.env.admin` - Admin panel environment variables

**Important**: All secrets in these files must be encrypted using the format `AES::@encrypted_value@`. The files are committed to the repository, but only with encrypted values.

## Working with the Project

### Prerequisites

1. **Docker and Docker Compose** installed
2. **OpenSSL** for encryption/decryption scripts
3. **Make** (optional, but recommended for convenience)

### Quick Start

1. **Check dependencies**:
```bash
make install
```

2. **Decrypt environment files** (first time setup):
```bash
make decrypt
```

3. **Start all services**:
```bash
make up
```

4. **Check service status**:
```bash
make status
```

### Common Commands

#### Service Management

```bash
make up              # Start all services (removes orphan containers)
make down            # Stop all services
make restart         # Restart all services
make ps              # Show container status
make logs            # Show logs for all services
make logs-traefik    # Show Traefik logs
make logs-client     # Show client logs
make logs-admin      # Show admin logs
```

#### Environment File Management

```bash
make encrypt              # Encrypt all .env files
make encrypt .env         # Encrypt specific file
make decrypt              # Decrypt all .env files
make decrypt .env         # Decrypt specific file
make edit .env            # Edit encrypted .env file
make set .env KEY=value   # Set specific value in .env
make check-secrets        # Verify all secrets are encrypted
```

#### Updates and Maintenance

```bash
make pull          # Update Docker images
make update        # Update images and restart services
make validate      # Validate configuration before deployment
make deploy        # Deploy project (validate + start)
make clean         # Remove all containers and volumes (with confirmation)
```

### Manual Script Usage

If you prefer to use scripts directly:

```bash
# Encrypt
./scripts/encrypt-env.sh [.env file]

# Decrypt
./scripts/decrypt-env.sh [.env file]

# Edit
./scripts/edit-env.sh [.env file] [KEY=value]

# Check
./scripts/check-env-secrets.sh [.env file]
```

## Environment File Encryption

### How It Works

1. **Encryption Format**: Values are encrypted using AES-256-CBC with PBKDF2
2. **Format**: `KEY=AES::@base64_encrypted_data@`
3. **Password**: Stored in `ENV_PASSWORD` environment variable or prompted interactively

### Workflow

1. **Editing secrets**:
   ```bash
   make edit .env
   # File is decrypted, opened in editor, then re-encrypted
   ```

2. **Setting a value**:
   ```bash
   make set .env DATABASE_URL=postgres://...
   ```

3. **Before committing**:
   ```bash
   make check-secrets
   # Ensures all secrets are encrypted
   ```

### Security Notes

- Never commit unencrypted secrets
- The pre-commit hook (if configured) will check encryption
- Use `ENV_PASSWORD` environment variable for automation
- Rotate encryption password periodically

## Deployment

### Automated Deployment (GitHub Actions)

The project uses GitHub Actions for automated deployment:

1. **Workflow**: `.github/workflows/deploy.yml`
2. **Trigger**: Manual workflow dispatch (can be run from any branch)
3. **Process**:
   - Fetches latest changes from the branch that triggered the workflow
   - Checks out and resets to the latest version of that branch
   - Decrypts .env files
   - Pulls latest Docker images
   - Stops containers
   - Starts containers with latest images
4. **Branch Support**: The workflow automatically detects and deploys the branch from which it was triggered (e.g., `main`, `feat/47/caddy-traefik`, etc.)

### Required GitHub Secrets

- `HOST` - Deployment server hostname/IP
- `USERNAME` - SSH username
- `SSH_KEY` - Private SSH key for server access
- `DEPLOY_PATH` - Path to project on server
- `ENV_PASSWORD` - Password for decrypting .env files

### Manual Deployment

1. **On the server**:
```bash
cd /path/to/project
git pull
make decrypt
make deploy
```

2. **Or using Docker Compose directly**:
```bash
docker compose down
docker compose up -d --pull always
```

## SSL Certificates

SSL certificates are automatically managed by Traefik using Let's Encrypt with DNS-01 challenge via Cloudflare:
- Certificates are automatically obtained and renewed
- Stored in Traefik volume (`traefik_data`)
- No manual certificate management required

**Required configuration**:
- `CLOUDFLARE_EMAIL` in `.env.traefik` - Email for Let's Encrypt
- `CLOUDFLARE_API_TOKEN` in `.env.traefik` - Cloudflare API token with DNS edit permissions

## Monitoring

Uptime Kuma is available at `status.liatoshynsky.com` for:
- Service uptime monitoring
- Health check status
- Incident tracking

## Troubleshooting

### Services Not Starting

1. **Check logs**:
```bash
make logs
```

2. **Check container status**:
```bash
make ps
```

3. **Verify environment files**:
```bash
make check-secrets
```

### Encryption Issues

1. **Verify password**:
```bash
make decrypt .env
```

2. **Re-encrypt if needed**:
```bash
make encrypt .env
```

### Certificate Issues

1. **Check Traefik logs**:
   ```bash
   make logs-traefik
   ```

2. **Verify Cloudflare credentials**:
   ```bash
   make decrypt .env.traefik
   # Check CLOUDFLARE_EMAIL and CLOUDFLARE_API_TOKEN
   ```

3. **Verify DNS-01 challenge**:
   - Ensure Cloudflare API token has DNS edit permissions
   - Check that domains point to the server IP

### Port Conflicts

If ports 80 or 443 are already in use:
1. Stop conflicting services
2. Or modify port mappings in `compose.yaml`

## Best Practices

1. **Always encrypt secrets** before committing
2. **Use Makefile commands** for consistency
3. **Check secrets** before deployment
4. **Monitor services** via uptime-kuma
5. **Keep images updated** with `make update`
6. **Backup environment files** (encrypted versions are in git)
7. **Test changes locally** before deploying

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Makefile Documentation](https://www.gnu.org/software/make/manual/)
