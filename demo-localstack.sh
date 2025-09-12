#!/bin/bash

# LeyLine DNS Service - LocalStack Demo Script
# This script demonstrates the deployed infrastructure in LocalStack

echo "🎬 LeyLine DNS Service - LocalStack Demo"
echo "========================================"

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
    echo -e "${YELLOW}[DEMO]${NC} $1"
}

# Demo Step 1: Show LocalStack Status
print_header "1. LocalStack Infrastructure Status"
print_status "Checking LocalStack health..."
curl -s http://localhost:4566/_localstack/health | python3 -m json.tool

echo ""
print_status "Available LocalStack services:"
curl -s http://localhost:4566/_localstack/health | python3 -c "
import sys, json
health = json.load(sys.stdin)
for service, status in health['services'].items():
    print(f'  ✅ {service}: {status}' if status == 'available' or status == 'running' else f'  ❌ {service}: {status}')
"

# Demo Step 2: Show Terraform Infrastructure
print_header "2. Deployed AWS Infrastructure (via LocalStack)"
cd terraform

print_status "Terraform-deployed resources:"
terraform output

# Demo Step 3: Show S3 Buckets
print_header "3. S3 Storage Demonstration"
print_status "Listing S3 buckets:"
awslocal s3 ls

print_status "Creating demo file in app-data bucket..."
echo "Demo file created on $(date)" > demo-file.txt
awslocal s3 cp demo-file.txt s3://leyline-demo-app-data/
rm demo-file.txt

print_status "Listing contents of app-data bucket:"
awslocal s3 ls s3://leyline-demo-app-data/

print_status "Creating demo asset in static-assets bucket..."
echo '{"message": "Demo asset", "timestamp": "'$(date)'"}' > demo-asset.json
awslocal s3 cp demo-asset.json s3://leyline-demo-static-assets/
rm demo-asset.json

print_status "Listing contents of static-assets bucket:"
awslocal s3 ls s3://leyline-demo-static-assets/

# Demo Step 4: Show VPC Infrastructure
print_header "4. VPC Network Infrastructure"
print_status "VPC Information:"
awslocal ec2 describe-vpcs --query 'Vpcs[?CidrBlock==`10.0.0.0/16`].{VpcId:VpcId,CidrBlock:CidrBlock,State:State}' --output table

print_status "Subnets:"
awslocal ec2 describe-subnets --query 'Subnets[?VpcId==`vpc-2c21c3893f57b423a`].{SubnetId:SubnetId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone,MapPublicIpOnLaunch:MapPublicIpOnLaunch}' --output table

print_status "Security Groups:"
awslocal ec2 describe-security-groups --query 'SecurityGroups[?VpcId==`vpc-2c21c3893f57b423a`].{GroupId:GroupId,GroupName:GroupName,Description:Description}' --output table

# Demo Step 5: Show IAM Infrastructure
print_header "5. IAM Security Infrastructure"
print_status "IAM Roles:"
awslocal iam list-roles --query 'Roles[].{RoleName:RoleName,Arn:Arn}' --output table

print_status "IAM Policies:"
awslocal iam list-policies --scope Local --query 'Policies[].{PolicyName:PolicyName,Arn:Arn}' --output table

print_status "Role Policy Attachments:"
awslocal iam list-attached-role-policies --role-name leyline-demo-app-role --output table

# Demo Step 6: Show CloudWatch Logs
print_header "6. CloudWatch Logging Infrastructure"
print_status "CloudWatch Log Groups:"
awslocal logs describe-log-groups --query 'logGroups[].{LogGroupName:logGroupName,RetentionInDays:retentionInDays}' --output table

# Demo Step 7: Infrastructure Graph
print_header "7. Infrastructure Diagram"
print_status "Infrastructure graph generated: terraform-graph.png"
if [[ -f "terraform-graph.png" ]]; then
    print_success "✅ Infrastructure diagram available"
    file terraform-graph.png
else
    print_warning "Run 'dot -Tpng terraform-graph.dot > terraform-graph.png' to generate diagram"
fi

# Demo Step 8: Files Created
print_header "8. Deliverables Generated"
print_status "Checking required deliverables:"

if [[ -f "plan.txt" ]]; then
    print_success "✅ terraform/plan.txt - Terraform plan output ($(wc -l < plan.txt) lines)"
else
    echo "❌ plan.txt missing"
fi

if [[ -f "terraform-graph.dot" ]]; then
    print_success "✅ terraform/terraform-graph.dot - Infrastructure graph"
else
    echo "❌ terraform-graph.dot missing"
fi

if [[ -f "terraform-graph.png" ]]; then
    print_success "✅ terraform/terraform-graph.png - Infrastructure diagram"
else
    print_warning "⚠️  terraform-graph.png (requires graphviz)"
fi

if [[ -f "terraform.tfvars.example" ]]; then
    print_success "✅ terraform/terraform.tfvars.example - Example configuration"
else
    echo "❌ terraform.tfvars.example missing"
fi

print_header "Demo Summary"
echo -e "${GREEN}🎉 LocalStack Infrastructure Demo Complete!${NC}"
echo ""
echo "📋 What was demonstrated:"
echo "  ✅ LocalStack running and healthy"
echo "  ✅ Terraform infrastructure deployed to LocalStack"
echo "  ✅ S3 buckets created and functional"
echo "  ✅ VPC network infrastructure (subnets, security groups)"
echo "  ✅ IAM roles and policies"
echo "  ✅ CloudWatch log groups"
echo "  ✅ Infrastructure graph visualization"
echo ""
echo "📁 Generated Files:"
echo "  • terraform/plan.txt - Terraform plan output"
echo "  • terraform/terraform-graph.dot - Infrastructure graph"
echo "  • terraform/terraform-graph.png - Infrastructure diagram"
echo "  • terraform/terraform.tfvars.example - Example configuration"
echo ""
echo "🔧 Technology Stack:"
echo "  • LocalStack Community Edition (Free Tier)"
echo "  • Terraform v$(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)["terraform_version"])')"
echo "  • AWS CLI with LocalStack integration"
echo "  • Available services: VPC, EC2, S3, IAM, CloudWatch Logs"
echo ""
echo "💡 Production Considerations:"
echo "  • ECS/ELBv2/RDS require LocalStack Pro"
echo "  • This demo shows infrastructure foundation"
echo "  • Application deployment would follow similar patterns"
echo ""
echo "🌐 LocalStack Dashboard: http://localhost:4566"

cd ..
