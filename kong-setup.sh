#!/bin/bash

# Kong API Gateway Setup Script
# This script sets up Kong with proper API key management

echo "Setting up Kong API Gateway..."

# Wait for Kong to be ready
echo "Waiting for Kong to be ready..."
until curl -f http://localhost:8001/status > /dev/null 2>&1; do
  echo "Waiting for Kong to be ready..."
  sleep 2
done

echo "Kong is ready! Setting up services and routes..."

# Create service
echo "Creating LeyLine API service..."
curl -i -X POST http://localhost:8001/services/ \
  --data "name=leyline-api" \
  --data "url=http://leyline:3000"

# Create route for health endpoint (no auth required)
echo "Creating health route..."
curl -i -X POST http://localhost:8001/services/leyline-api/routes \
  --data "name=health-route" \
  --data "paths[]=/health" \
  --data "strip_path=false"

# Create route for API endpoints (auth required)
echo "Creating API routes..."
curl -i -X POST http://localhost:8001/services/leyline-api/routes \
  --data "name=api-route" \
  --data "paths[]=/v1" \
  --data "strip_path=false"

# Create route for metrics (auth required)
curl -i -X POST http://localhost:8001/services/leyline-api/routes \
  --data "name=metrics-route" \
  --data "paths[]=/metrics" \
  --data "strip_path=false"

# Create route for root endpoint (auth required)
curl -i -X POST http://localhost:8001/services/leyline-api/routes \
  --data "name=root-route" \
  --data "paths[]=/" \
  --data "strip_path=false"

# Enable key-auth plugin for API routes
echo "Enabling API key authentication..."
curl -i -X POST http://localhost:8001/routes/api-route/plugins \
  --data "name=key-auth"

curl -i -X POST http://localhost:8001/routes/metrics-route/plugins \
  --data "name=key-auth"

curl -i -X POST http://localhost:8001/routes/root-route/plugins \
  --data "name=key-auth"

# Enable rate limiting for all routes
echo "Setting up rate limiting..."
curl -i -X POST http://localhost:8001/routes/health-route/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=100" \
  --data "config.hour=1000"

curl -i -X POST http://localhost:8001/routes/api-route/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=20" \
  --data "config.hour=200"

curl -i -X POST http://localhost:8001/routes/metrics-route/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=10" \
  --data "config.hour=100"

curl -i -X POST http://localhost:8001/routes/root-route/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=10" \
  --data "config.hour=100"

# Enable request size limiting
echo "Setting up request size limiting..."
curl -i -X POST http://localhost:8001/services/leyline-api/plugins \
  --data "name=request-size-limiting" \
  --data "config.allowed_payload_size=1024"

# Enable CORS
echo "Setting up CORS..."
curl -i -X POST http://localhost:8001/services/leyline-api/plugins \
  --data "name=cors" \
  --data "config.origins=*" \
  --data "config.methods=GET,POST,PUT,DELETE,OPTIONS" \
  --data "config.headers=Accept,Accept-Version,Content-Length,Content-MD5,Content-Type,Date,X-Auth-Token,Authorization" \
  --data "config.exposed_headers=X-Auth-Token" \
  --data "config.credentials=true" \
  --data "config.max_age=3600"

# Create consumers and API keys
echo "Creating consumers and API keys..."

# Create leyline-client consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=leyline-client" \
  --data "custom_id=leyline-client-001"

# Create admin consumer
curl -i -X POST http://localhost:8001/consumers/ \
  --data "username=admin" \
  --data "custom_id=admin-001"

# Create API keys
echo "Creating API keys..."

# Standard API key
curl -i -X POST http://localhost:8001/consumers/leyline-client/key-auth \
  --data "key=leyline-api-key-2024" \
  --data "tags[]=standard"

# Admin API key
curl -i -X POST http://localhost:8001/consumers/admin/key-auth \
  --data "key=admin-key-2024" \
  --data "tags[]=admin"

# Test API key
curl -i -X POST http://localhost:8001/consumers/leyline-client/key-auth \
  --data "key=test-key-2024" \
  --data "tags[]=test"

echo ""
echo "✅ Kong setup completed successfully!"
echo ""
echo "📋 API Keys created:"
echo "  - leyline-api-key-2024 (standard access)"
echo "  - admin-key-2024 (admin access)"
echo "  - test-key-2024 (test access)"
echo ""
echo "🌐 Access URLs:"
echo "  - Kong Admin API: http://localhost:8001"
echo "  - Kong Gateway: http://localhost:8000"
echo "  - Kong Admin GUI: http://localhost:8002"
echo "  - LeyLine API: http://localhost:8000"
echo ""
echo "🔑 Test API access:"
echo "  curl -H 'X-API-Key: leyline-api-key-2024' http://localhost:8000/"
echo ""
echo "📊 View API keys:"
echo "  curl http://localhost:8001/consumers/leyline-client/key-auth"
echo ""
