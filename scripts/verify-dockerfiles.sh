#!/bin/bash

# verify-dockerfiles.sh
# Script to verify all required Dockerfiles exist before running GitHub workflow

set -e

echo "🔍 Verifying Dockerfiles for Lunchbox Services"
echo "=============================================="
echo ""

SERVICES=(
    "certbot"
    "nginx"
    "php-fpm"
    "postgres"
    "pgbouncer"
    "redis"
    "rabbitmq"
    "portainer"
    "minio"
)

ALL_VALID=true

for service in "${SERVICES[@]}"; do
    dockerfile_path="./$service/Dockerfile"

    if [ -f "$dockerfile_path" ]; then
        echo "✅ $service: Dockerfile found at $dockerfile_path"
    else
        echo "❌ $service: Dockerfile NOT found at $dockerfile_path"
        ALL_VALID=false
    fi
done

echo ""
if [ "$ALL_VALID" = true ]; then
    echo "🎉 All Dockerfiles are present and ready for GitHub workflow!"
    echo "   You can now push your code to trigger the build process."
else
    echo "⚠️  Some Dockerfiles are missing. Please check the paths above."
    echo "   The GitHub workflow will fail if Dockerfiles are missing."
    exit 1
fi

echo ""
echo "📋 Service contexts for reference:"
for service in "${SERVICES[@]}"; do
    echo "   - $service: ./$service"
done
