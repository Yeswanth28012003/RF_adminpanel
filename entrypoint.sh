#!/bin/sh

set -e

echo "=> Running database migrations..."
python manage.py migrate --noinput

echo "=> Collecting static files..."
python manage.py collectstatic --noinput

echo "=> Creating logs directory..."
mkdir -p /app/logs

# Create superuser if it doesn't exist (only when env vars are set)
if [ -n "$DJANGO_SUPERUSER_USERNAME" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "=> Checking for existing superuser..."
    python manage.py createsuperuser --noinput 2>/dev/null || true
fi

echo "=> Starting Gunicorn..."
exec gunicorn rf_adminpanel.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers ${GUNICORN_WORKERS:-3} \
    --threads ${GUNICORN_THREADS:-2} \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --capture-output