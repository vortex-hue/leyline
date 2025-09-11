#!/bin/bash

# LeyLine DNS Service - Stop All Services Script

echo "🛑 Stopping LeyLine DNS Service - Complete Stack"
echo "==============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Stop Kong API Gateway
print_status "Stopping Kong API Gateway..."
docker-compose -f docker-compose.kong.yml down

# Stop observability stack
print_status "Stopping observability stack..."
docker-compose -f docker-compose.observability.yml down

# Stop main application
print_status "Stopping main application..."
docker-compose down

# Clean up any orphaned containers
print_status "Cleaning up orphaned containers..."
docker-compose -f docker-compose.kong.yml down --remove-orphans
docker-compose -f docker-compose.observability.yml down --remove-orphans
docker-compose down --remove-orphans

print_success "All services stopped successfully!"
