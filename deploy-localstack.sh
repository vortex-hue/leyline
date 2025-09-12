#!/bin/bash

# LeyLine DNS Service - LocalStack Deployment Script
# This script deploys the infrastructure to LocalStack for demonstration

echo "🚀 LeyLine DNS Service - LocalStack Deployment"
echo "=============================================="

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if LocalStack is running
print_status "Checking if LocalStack is running..."
if ! curl -f -s http://localhost:4566/health > /dev/null 2>&1; then
    print_warning "LocalStack not running. Starting LocalStack..."
    docker-compose up -d localstack
    
    print_status "Waiting for LocalStack to be ready..."
    for i in {1..30}; do
        if curl -f -s http://localhost:4566/health > /dev/null 2>&1; then
            print_success "LocalStack is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
else
    print_success "LocalStack is already running!"
fi

# Check LocalStack status
print_status "LocalStack status:"
curl -s http://localhost:4566/health | python3 -m json.tool

echo ""
print_status "Available LocalStack services:"
curl -s http://localhost:4566/health | python3 -c "import sys, json; print('\n'.join(json.load(sys.stdin)['services'].keys()))"

# Change to terraform directory
cd terraform

# Initialize Terraform
print_status "Initializing Terraform..."
if terraform init; then
    print_success "Terraform initialized successfully!"
else
    print_error "Terraform initialization failed!"
    exit 1
fi

# Create terraform.tfvars from example
if [[ ! -f "terraform.tfvars" ]]; then
    print_status "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    print_success "Created terraform.tfvars"
fi

# Generate Terraform plan
print_status "Generating Terraform plan..."
if terraform plan -out=plan.txt -detailed-exitcode; then
    PLAN_EXIT_CODE=$?
    if [[ $PLAN_EXIT_CODE -eq 2 ]]; then
        print_success "Terraform plan generated successfully! (Changes detected)"
    else
        print_success "Terraform plan generated successfully! (No changes)"
    fi
else
    print_error "Terraform plan failed!"
    exit 1
fi

# Apply Terraform configuration
print_status "Applying Terraform configuration to LocalStack..."
if terraform apply -auto-approve plan.txt; then
    print_success "Infrastructure deployed to LocalStack successfully!"
else
    print_error "Terraform apply failed!"
    exit 1
fi

# Generate Terraform graph
print_status "Generating infrastructure diagram..."
terraform graph > terraform-graph.dot

# Convert to PNG if dot is available
if command -v dot >/dev/null 2>&1; then
    dot -Tpng terraform-graph.dot > terraform-graph.png
    print_success "Infrastructure diagram saved as terraform-graph.png"
else
    print_warning "Graphviz 'dot' not found. Install with: brew install graphviz"
    print_status "Terraform graph saved as terraform-graph.dot"
fi

# Show infrastructure status
echo ""
print_status "Deployment Summary:"
echo "==================="

# Show Terraform outputs
print_status "Terraform outputs:"
terraform output

echo ""
print_status "LocalStack Resources Created:"

# Check ECS clusters
print_status "ECS Clusters:"
awslocal ecs list-clusters --endpoint-url http://localhost:4566 2>/dev/null || echo "  No ECS clusters found"

# Check VPC
print_status "VPCs:"
awslocal ec2 describe-vpcs --endpoint-url http://localhost:4566 --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "  No VPCs found"

# Check Load Balancers
print_status "Load Balancers:"
awslocal elbv2 describe-load-balancers --endpoint-url http://localhost:4566 --query 'LoadBalancers[].LoadBalancerName' --output text 2>/dev/null || echo "  No Load Balancers found"

echo ""
print_success "🎉 LocalStack deployment completed successfully!"
echo ""
echo "📋 Generated Files:"
echo "  ✅ terraform/plan.txt - Terraform plan output"
echo "  ✅ terraform/terraform-graph.dot - Infrastructure graph"
if [[ -f "terraform-graph.png" ]]; then
    echo "  ✅ terraform/terraform-graph.png - Infrastructure diagram"
fi
echo "  ✅ terraform/terraform.tfvars.example - Example configuration"
echo ""
echo "🌐 LocalStack Dashboard: http://localhost:4566"
echo "📊 LocalStack Health: http://localhost:4566/health"
echo ""
echo "🧪 Test Commands:"
echo "  awslocal ecs list-clusters"
echo "  awslocal ec2 describe-vpcs"
echo "  awslocal elbv2 describe-load-balancers"
echo ""
echo "🛑 To destroy infrastructure: terraform destroy -auto-approve"
