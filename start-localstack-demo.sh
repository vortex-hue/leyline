#!/bin/bash

# LeyLine DNS Service - LocalStack Demo with Full Observability
# This script demonstrates the complete solution with LocalStack

echo "🚀 LeyLine DNS Service - LocalStack Demo with Observability"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================================${NC}"
}

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
docker-compose -f docker-compose.localstack-observability.yml down > /dev/null 2>&1
docker-compose down > /dev/null 2>&1
docker container prune -f > /dev/null 2>&1

print_header "Phase 1: Starting LocalStack Demo Environment"

# Start the complete LocalStack observability stack
print_status "Starting LocalStack demo with full observability stack..."
docker-compose -f docker-compose.localstack-observability.yml up -d

# Wait for core services
print_status "Waiting for core services to initialize..."
sleep 20

# Health checks
print_header "Phase 2: Service Health Verification"

# Check LocalStack
print_status "Checking LocalStack health..."
for i in {1..20}; do
    if curl -f -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
        print_success "LocalStack is ready!"
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

# Check application
print_status "Checking application health..."
for i in {1..20}; do
    if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
        print_success "Application is ready!"
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

# Check Prometheus
print_status "Checking Prometheus health..."
for i in {1..20}; do
    if curl -f -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        print_success "Prometheus is ready!"
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

# Check Grafana
print_status "Checking Grafana health..."
for i in {1..20}; do
    if curl -f -s http://localhost:3001/api/health > /dev/null 2>&1; then
        print_success "Grafana is ready!"
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

print_header "Phase 3: Infrastructure Deployment"

# Deploy infrastructure to LocalStack
print_status "Deploying infrastructure to LocalStack..."
cd terraform

# Initialize and deploy
terraform init > /dev/null 2>&1
if terraform plan -out=localstack-plan.txt > /dev/null 2>&1; then
    print_success "Terraform plan generated successfully!"
    
    if terraform apply -auto-approve localstack-plan.txt > /dev/null 2>&1; then
        print_success "Infrastructure deployed to LocalStack!"
        
        # Generate graph
        terraform graph > localstack-terraform-graph.dot
        if command -v dot >/dev/null 2>&1; then
            dot -Tpng localstack-terraform-graph.dot > localstack-terraform-graph.png
            print_success "Infrastructure diagram generated!"
        fi
    else
        print_error "Infrastructure deployment failed!"
    fi
else
    print_error "Terraform plan failed!"
fi

cd ..

print_header "Phase 4: Testing Application & API Management"

# Test direct application endpoints
print_status "Testing application endpoints..."

# Health check
if curl -f -s http://localhost:3000/health > /dev/null; then
    print_success "✅ Health endpoint working"
else
    print_error "❌ Health endpoint failed"
fi

# Metrics
if curl -f -s http://localhost:3000/metrics > /dev/null; then
    print_success "✅ Metrics endpoint working"
else
    print_error "❌ Metrics endpoint failed"
fi

# Authenticated endpoint
if curl -f -s -H "X-API-Key: leyline-api-key-2024" http://localhost:3000/ > /dev/null; then
    print_success "✅ Authenticated endpoint working"
else
    print_error "❌ Authenticated endpoint failed"
fi

# DNS lookup
if curl -f -s -H "X-API-Key: leyline-api-key-2024" "http://localhost:3000/v1/tools/lookup?domain=example.com" > /dev/null; then
    print_success "✅ DNS lookup working"
else
    print_error "❌ DNS lookup failed"
fi

print_header "Phase 5: Generating Load for Metrics"

# Generate some load to populate metrics
print_status "Generating load to populate metrics and dashboards..."

for i in {1..20}; do
    # Health checks
    curl -f -s http://localhost:3000/health > /dev/null 2>&1 &
    
    # Authenticated requests
    curl -f -s -H "X-API-Key: leyline-api-key-2024" http://localhost:3000/ > /dev/null 2>&1 &
    
    # DNS lookups
    curl -f -s -H "X-API-Key: leyline-api-key-2024" "http://localhost:3000/v1/tools/lookup?domain=example.com" > /dev/null 2>&1 &
    curl -f -s -H "X-API-Key: leyline-api-key-2024" "http://localhost:3000/v1/tools/lookup?domain=google.com" > /dev/null 2>&1 &
    
    # IP validation
    curl -f -s -H "X-API-Key: leyline-api-key-2024" "http://localhost:3000/v1/tools/validate?ip=8.8.8.8" > /dev/null 2>&1 &
    
    # Some invalid requests to generate errors
    if [ $((i % 5)) -eq 0 ]; then
        curl -f -s http://localhost:3000/ > /dev/null 2>&1 &  # Missing API key
        curl -f -s -H "X-API-Key: invalid-key" http://localhost:3000/ > /dev/null 2>&1 &  # Invalid API key
    fi
done

wait

print_success "Load generation completed!"

print_header "Phase 6: Verifying Observability Stack"

# Wait for metrics to be scraped
print_status "Waiting for metrics to be collected..."
sleep 30

# Check Prometheus targets
print_status "Checking Prometheus targets..."
if curl -s http://localhost:9090/api/v1/targets | grep -q "leyline-dns-service-localstack"; then
    print_success "✅ Prometheus is scraping application metrics"
else
    print_warning "⚠️  Prometheus target configuration may need adjustment"
fi

# Check if metrics are available
print_status "Checking available metrics..."
if curl -s http://localhost:9090/api/v1/query?query=up | grep -q "leyline-dns-service-localstack"; then
    print_success "✅ Application metrics available in Prometheus"
else
    print_warning "⚠️  Application metrics may need time to appear"
fi

print_header "Phase 7: Demo Summary"

print_success "🎉 LocalStack Demo with Observability is ready!"
echo ""
echo "📊 Service URLs:"
echo "  🏥 Application Health:    http://localhost:3000/health"
echo "  📈 Application Metrics:   http://localhost:3000/metrics"
echo "  🔍 Application API:       http://localhost:3000/docs"
echo ""
echo "🔧 Infrastructure:"
echo "  ☁️  LocalStack:           http://localhost:4566/_localstack/health"
echo "  🏗️  LocalStack Dashboard: http://localhost:4566"
echo ""
echo "📊 Observability Stack:"
echo "  📊 Prometheus:            http://localhost:9090"
echo "  📈 Grafana:               http://localhost:3001 (admin/admin123)"
echo "  🚨 AlertManager:          http://localhost:9093"
echo ""
echo "🔍 System Monitoring:"
echo "  📊 Node Exporter:         http://localhost:9100"
echo "  🐳 cAdvisor:              http://localhost:8080"
echo ""
echo "🧪 Test Commands:"
echo "  curl http://localhost:3000/health"
echo "  curl -H 'X-API-Key: leyline-api-key-2024' http://localhost:3000/"
echo "  curl -H 'X-API-Key: leyline-api-key-2024' 'http://localhost:3000/v1/tools/lookup?domain=example.com'"
echo ""
echo "🎨 Grafana Dashboards:"
echo "  • LocalStack Demo Dashboard: http://localhost:3001/d/localstack-demo"
echo "  • Default credentials: admin / admin123"
echo ""
echo "📁 Generated Artifacts:"
if [[ -f "terraform/localstack-plan.txt" ]]; then
    echo "  ✅ terraform/localstack-plan.txt"
fi
if [[ -f "terraform/localstack-terraform-graph.png" ]]; then
    echo "  ✅ terraform/localstack-terraform-graph.png"
fi
echo ""
echo "🎬 What's Demonstrated:"
echo "  ✅ LocalStack AWS infrastructure emulation"
echo "  ✅ Containerized FastAPI application"
echo "  ✅ API key authentication and rate limiting"
echo "  ✅ Comprehensive observability (metrics, logs, alerts)"
echo "  ✅ Infrastructure as Code with Terraform"
echo "  ✅ Real-time monitoring dashboards"
echo "  ✅ Automated alerting system"
echo ""
echo "🛑 To stop all services: docker-compose -f docker-compose.localstack-observability.yml down"
