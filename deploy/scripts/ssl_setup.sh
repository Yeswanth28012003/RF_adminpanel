#!/bin/bash
#
# SSL certificate setup with Certbot (webroot mode)
# Run AFTER the app is up and DNS points to this server:
#   bash deploy/scripts/ssl_setup.sh
#
# Requires: certbot installed on the HOST (or run as root)
#
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/../.."

# Helper: read a key from .env without sourcing (values may contain special chars)
get_env() {
    grep -E "^$1=" .env | tail -1 | head -1 | cut -d'=' -f2- | tr -d '\r'
}

if [ ! -f ".env" ]; then
    echo -e "${RED}ERROR: .env file not found.${NC}"
    exit 1
fi

DOMAIN_NAME=$(get_env DOMAIN_NAME)
SSL_EMAIL=$(get_env SSL_EMAIL)

if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" = "admin.yourdomain.com" ]; then
    echo -e "${RED}ERROR: DOMAIN_NAME not set correctly in .env${NC}"
    exit 1
fi

echo -e "${GREEN}==> Requesting SSL certificate for $DOMAIN_NAME${NC}"
echo -e "${YELLOW}Ensure the DNS A record for $DOMAIN_NAME points to this server.${NC}"

# Verify DNS resolves to this machine before requesting a cert
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
DOMAIN_IP=$(dig +short "$DOMAIN_NAME" 2>/dev/null | grep -E '^[0-9]+\.' | head -1)

if [ -n "$DOMAIN_IP" ] && [ -n "$HOST_IP" ] && [ "$DOMAIN_IP" != "$HOST_IP" ]; then
    echo -e "${YELLOW}Warning: $DOMAIN_NAME resolves to $DOMAIN_IP, but this server is $HOST_IP${NC}"
    echo -e "${YELLOW}Continuing anyway...${NC}"
fi

if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot not found on host. Attempting install...${NC}"
    sudo apt-get update
    sudo apt-get install -y certbot
fi

echo "=> Preparing webroot..."
mkdir -p deploy/certbot/www

echo "=> Issuing certificate..."
sudo certbot certonly --webroot \
    -w "$(pwd)/deploy/certbot/www" \
    -d "$DOMAIN_NAME" \
    --email "${SSL_EMAIL:-admin@$DOMAIN_NAME}" \
    --agree-tos \
    --no-eff-email \
    --non-interactive || {
        echo -e "${RED}Certbot failed. Common causes:${NC}"
        echo "  1. DNS has not propagated yet - wait and re-run"
        echo "  2. Port 80 is not reachable from the internet"
        echo "  3. Domain is already issued - run: sudo certbot renew"
        exit 1
    }

echo "=> Reloading nginx with HTTPS config..."
docker compose restart nginx

echo -e "${GREEN}==> SSL setup complete. HTTPS is now active.${NC}"
echo ""
echo "Add auto-renewal to cron (run as root):"
echo "  echo '0 3 * * *  certbot renew --quiet --deploy-hook \"docker compose -f $(pwd)/docker-compose.yml exec nginx nginx -s reload\"' | sudo tee /etc/cron.d/certbot-renew"