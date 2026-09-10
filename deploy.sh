#!/bin/bash
#
# Deployment script for RF Admin Panel (production)
# Run on the server: bash deploy.sh
#
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}==> RF Admin Panel Deployment${NC}"

cd "$(dirname "$0")"

# Helper: read a key from .env without sourcing (values may contain special chars)
get_env() {
    grep -E "^$1=" .env | tail -1 | head -1 | cut -d'=' -f2- | tr -d '\r'
}

# 1. Load environment variables
if [ ! -f ".env" ]; then
    echo -e "${RED}ERROR: .env file not found. Copy .env.example to .env and configure it.${NC}"
    exit 1
fi

DOMAIN_NAME=$(get_env DOMAIN_NAME)
SECRET_KEY=$(get_env SECRET_KEY)
DEBUG_VAL=$(get_env DEBUG)

if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" = "admin.yourdomain.com" ]; then
    echo -e "${RED}ERROR: Set DOMAIN_NAME in .env to your actual domain before deploying.${NC}"
    exit 1
fi

# 2. Substitute the domain into the nginx config
echo "=> Configuring nginx for domain: $DOMAIN_NAME"
sed -i "s/__DOMAIN_NAME__/$DOMAIN_NAME/g" deploy/nginx/nginx.conf

# 3. Generate a secure secret key if not set
if [ -z "$SECRET_KEY" ]; then
    echo "=> Generating a secure SECRET_KEY..."
    NEW_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(64))" 2>/dev/null || openssl rand -hex 32)
    sed -i "s/^SECRET_KEY=.*/SECRET_KEY=${NEW_KEY}/" .env
    echo "=> SECRET_KEY written to .env"
fi

# 4. Ensure DEBUG=False in .env
sed -i 's/^DEBUG=.*/DEBUG=False/' .env

# 5. Build and start containers
echo "=> Building Docker images..."
docker compose build

echo "=> Starting services..."
docker compose up -d

# 6. Show status
echo -e "${GREEN}==> Deployment complete.${NC}"
echo -e "${GREEN}==> Check status: docker compose ps${NC}"
echo -e "${GREEN}==> View logs: docker compose logs -f app${NC}"

echo
echo "Next steps:"
echo "  1. Point your domain DNS (A record) to this server's IP"
echo "  2. Run: bash deploy/scripts/ssl_setup.sh  (to get an HTTPS certificate)"