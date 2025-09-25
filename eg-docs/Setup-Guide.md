# LibreChat Setup Guide

## Overview

LibreChat is an open-source ChatGPT clone that supports multiple AI providers. This guide covers complete setup from infrastructure to deployment.

## Infrastructure Requirements

### Server Specifications
- **AWS Instance**: t3.medium
- **CPU**: 2 vCPUs
- **RAM**: 4GB
- **Storage**: 32GB minimum (Run `docker system prune -a` after updates to clean up old images)
- **OS**: Ubuntu 22.04 LTS (official) or Debian (tested)

## Repository Information
- **Official Repository**: https://github.com/danny-avila/LibreChat
- **E-gineering Fork**: https://github.com/e-gineering/LibreChat

## Initial Server Setup
After basic provisioning of the VM and ensuring SSH access:

### Docker Setup

- **Official Remote Docker Linux Install guide**: [LibreChat Docs](https://www.librechat.ai/docs/remote/docker_linux)

### Repository Setup
```sh
# Clone repository
git clone https://github.com/e-gineering/LibreChat.git
# Or the upstream repo: git clone https://github.com/danny-avila/LibreChat.git

# Enter project directory
cd LibreChat
```
## Configuration

### Core Configuration Files
1. `docker-compose.override.yml` - Docker service overrides  
2. `librechat.yaml` - Application configuration
3. `.env` - Environment variables

### Setup Process

**Copy Template Files:**
```sh
# Copy template configuration files
cp eg.docker-compose.override.yml.example docker-compose.override.yml
cp eg.librechat.example.yaml librechat.yaml
cp .env.example .env
```

### Environment Variables (.env)

Generate secure credentials at: https://www.librechat.ai/toolkit/creds_generator

**Essential variables to update:**
```env
# domain information
HOST=
DOMAIN_CLIENT=
DOMAIN_SERVER=

# Credentials
CREDS_IV=
CREDS_KEY=
JWT_SECRET=
JWT_REFRESH_SECRET=
MEILI_MASTER_KEY=

# AI Provider Keys - set to `user_provided` to have individual keys.
OPENAI_API_KEY=sk-your_key_here

# Disable registration after creating admin account (by default its the first account)
ALLOW_REGISTRATION=false

# RAG for retrieval augmented generation
RAG_API_URL=
RAG_OPENAI_API_KEY=

# OCR for "optical character recognition"
OCR_API_KEY=
```

Moderation options. Rate limiting options might be too strict if you're all using it at the same time from the same location

```env
LIMIT_MESSAGE_IP=false
MESSAGE_IP_MAX=120
MESSAGE_IP_WINDOW=1
```
* SSO login with Microsoft can be configured using the information here: [LibreChat SAML Docs](https://www.librechat.ai/docs/configuration/authentication/SAML)

### Docker Compose Override

This file is used to volume map the `librechat.yaml` file into the container. And to start up any extra containers like traefik, nginx, or metrics for example. This basically runs on top of, and "overrides" the `docker-compose.yml`.

### Librechat.yaml

Additional providers, endpoints, and MCP servers can be added here in the `librechat.yaml`. As well as Terms of Service modal, and other configuration options. 
See [Librechat.yaml docs](https://www.librechat.ai/docs/configuration/librechat_yaml) for more information.

## Deployment

```sh
docker compose up -d
```

## Updates

Update the LibreChat version in the override file and then run:

```sh
docker compose pull && docker compose down && docker compose up -d
```

After its confirmed working you can run this to clean up the old images, etc.

```sh
docker system prune -a
```
