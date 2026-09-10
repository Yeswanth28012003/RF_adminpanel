FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DJANGO_SETTINGS_MODULE=rf_adminpanel.settings

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies first (better layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy project
COPY . .

# Create data/log dirs and non-root user (dirs must exist & be owned by appuser
# so the Docker named volumes inherit correct permissions)
RUN mkdir -p /app/data /app/logs /app/media /app/staticfiles && \
    useradd --create-home appuser && \
    chown -R appuser:appuser /app
USER appuser

# Port for Gunicorn
EXPOSE 8000

# Entrypoint runs migrations + collectstatic then starts Gunicorn
# Invoked via `sh` so it works even if the exec bit is not preserved from Windows
ENTRYPOINT ["sh", "./entrypoint.sh"]