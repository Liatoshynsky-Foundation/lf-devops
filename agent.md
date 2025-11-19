# Project Documentation

This document describes the Liatoshynsky Foundation DevOps infrastructure project, its structure, and how to work with it.

## Overview

This repository contains the DevOps infrastructure for the Liatoshynsky Foundation web services. It manages deployment and configuration of multiple services using Docker Compose, with Caddy as a reverse proxy and SSL termination.

## Project Structure

```
lf-devops/
├── compose.yaml          # Docker Compose configuration
├── Caddyfile             # Caddy reverse proxy configuration
├── Makefile              # Convenience commands for project management
├── agent.md              # This documentation file
├── scripts/              # Utility scripts
│   ├── env-crypto.sh     # Common encryption/decryption functions
│   ├── encrypt-env.sh    # Encrypt .env files
│   ├── decrypt-env.sh    # Decrypt .env files
│   ├── edit-env.sh       # Edit encrypted .env files
│   └── check-env-secrets.sh  # Verify all secrets are encrypted
└── caddy/
    └── certs/            # SSL certificates (gitignored)
```

## Services

The infrastructure consists of the following services:

### 1. Caddy (Reverse Proxy)
- **Container**: `caddy`
- **Ports**: 80, 443
- **Purpose**: Reverse proxy with SSL/TLS termination
- **Configuration**: `Caddyfile`
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

- `.env` - Main environment variables (used by caddy and lf-placeholder)
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
make logs-caddy      # Show Caddy logs
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
2. **Trigger**: Manual workflow dispatch (or push to main if enabled)
3. **Process**:
   - Pulls latest changes on server
   - Decrypts .env files
   - Stops containers
   - Starts containers with latest images

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

SSL certificates are stored in `caddy/certs/`:
- `origin.pem` - Certificate file
- `origin.key` - Private key file

**Note**: This directory is gitignored. Certificates must be manually placed on the server.

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

1. **Verify certificates exist**:
```bash
ls -la caddy/certs/
```

2. **Check Caddy logs**:
```bash
make logs-caddy
```

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
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Makefile Documentation](https://www.gnu.org/software/make/manual/)
