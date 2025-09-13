#!/bin/bash

# Cleanup script to remove all containers and prevent conflicts
# This script helps prevent the "container name already in use" error

echo "🧹 Cleaning up Docker containers..."

# Stop and remove all containers from docker-compose files
echo "Stopping docker-compose services..."
docker-compose -f docker-compose.localstack-observability.yml down --remove-orphans 2>/dev/null || true
docker-compose -f docker-compose.kong.yml down --remove-orphans 2>/dev/null || true
docker-compose -f docker-compose.yml down --remove-orphans 2>/dev/null || true

# Remove specific containers that might be running
echo "Removing specific containers..."
docker rm -f localstack redis postgres kong kong-database kong-migration kong-setup prometheus grafana alertmanager node-exporter cadvisor redis-exporter postgres-exporter leyline-api 2>/dev/null || true

# Remove any stopped containers
echo "Removing stopped containers..."
docker container prune -f 2>/dev/null || true

# Clean up unused images
echo "Cleaning up unused images..."
docker image prune -f 2>/dev/null || true

# Clean up unused volumes
echo "Cleaning up unused volumes..."
docker volume prune -f 2>/dev/null || true

# Clean up unused networks
echo "Cleaning up unused networks..."
docker network prune -f 2>/dev/null || true

echo "✅ Cleanup completed! All containers have been removed."
echo "You can now run your services without conflicts."
