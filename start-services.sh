#!/bin/bash

# LeyLine DNS Service - Complete Startup Script
# This script starts all services with proper configuration

echo "🚀 Starting LeyLine DNS Service - Complete Stack"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

print_status "Docker is running ✓"

# Stop any existing containers
print_status "Stopping existing containers..."
docker-compose -f docker-compose.kong.yml down > /dev/null 2>&1
docker-compose down > /dev/null 2>&1
docker-compose -f docker-compose.observability.yml down > /dev/null 2>&1

# Start the main application stack
print_status "Starting main application stack..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 10

# Start Kong API Gateway
print_status "Starting Kong API Gateway..."
docker-compose -f docker-compose.kong.yml up -d

# Wait for Kong to be ready
print_status "Waiting for Kong to be ready..."
sleep 15

# Setup Kong configuration
print_status "Setting up Kong API Gateway configuration..."
./kong-setup.sh

# Start observability stack
print_status "Starting observability stack..."
docker-compose -f docker-compose.observability.yml up -d

# Wait for all services to be ready
print_status "Waiting for all services to be ready..."
sleep 20

# Check service health
print_status "Checking service health..."

# Check main application
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    print_success "Main application is healthy"
else
    print_error "Main application is not responding"
fi

# Check Kong Gateway
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    print_success "Kong Gateway is healthy"
else
    print_error "Kong Gateway is not responding"
fi

# Check Prometheus
if curl -f http://localhost:9090/-/healthy > /dev/null 2>&1; then
    print_success "Prometheus is healthy"
else
    print_warning "Prometheus is not responding (may take time to start)"
fi

# Check Grafana
if curl -f http://localhost:3001/api/health > /dev/null 2>&1; then
    print_success "Grafana is healthy"
else
    print_warning "Grafana is not responding (may take time to start)"
fi

echo ""
echo "🎉 LeyLine DNS Service is now running!"
echo "======================================"
echo ""
echo "📋 Service URLs:"
echo "  🌐 Kong Gateway:        http://localhost:8000"
echo "  🔧 Kong Admin API:      http://localhost:8001"
echo "  🎛️  Kong Admin GUI:      http://localhost:8002"
echo "  🚀 LeyLine API:         http://localhost:3000"
echo "  📚 API Documentation:   http://localhost:3000/docs"
echo "  📊 Grafana Dashboard:   http://localhost:3001 (admin/admin123)"
echo "  📈 Prometheus Metrics:  http://localhost:9090"
echo "  🔑 API Key Manager:     file://$(pwd)/api-key-manager.html"
echo ""
echo "🔑 API Keys:"
echo "  • leyline-api-key-2024 (Standard access)"
echo "  • admin-key-2024 (Admin access)"
echo "  • test-key-2024 (Test access)"
echo ""
echo "🧪 Test Commands:"
echo "  # Health check (no auth)"
echo "  curl http://localhost:8000/health"
echo ""
echo "  # API call with authentication"
echo "  curl -H 'X-API-Key: leyline-api-key-2024' http://localhost:8000/"
echo ""
echo "  # DNS lookup"
echo "  curl -X POST -H 'X-API-Key: leyline-api-key-2024' \\"
echo "    'http://localhost:8000/v1/tools/lookup?domain=example.com'"
echo ""
echo "  # View API keys in Kong"
echo "  curl http://localhost:8001/consumers/leyline-client/key-auth"
echo ""
echo "📊 Monitoring:"
echo "  • Open Grafana: http://localhost:3001"
echo "  • Username: admin"
echo "  • Password: admin123"
echo "  • Dashboard: LeyLine DNS Service - Production Dashboard"
echo ""
echo "🛑 To stop all services:"
echo "  ./stop-services.sh"
echo ""

# Open API Key Manager in browser (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_status "Opening API Key Manager in browser..."
fi

print_success "Setup complete! All services are running."
