# LocalStack Free Tier Demo Configuration
# Only uses services available in LocalStack Community Edition

# Create a VPC
resource "aws_vpc" "demo" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Demo        = "LocalStack-Free-Tier"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.demo.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Type        = "Public"
    Environment = var.environment
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.demo.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Type        = "Private"
    Environment = var.environment
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.demo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for Web Servers
resource "aws_security_group" "web" {
  name_prefix = "${var.project_name}-web-"
  vpc_id      = aws_vpc.demo.id
  description = "Security group for web servers"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App Port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# CloudWatch Log Group (available in LocalStack)
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/demo/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
  }
}

# S3 Bucket for demonstration
resource "aws_s3_bucket" "app_data" {
  bucket = "${var.project_name}-${var.environment}-app-data"

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-data"
    Environment = var.environment
    Purpose     = "Application Data"
  }
}

# S3 Bucket for static assets
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.project_name}-${var.environment}-static-assets"

  tags = {
    Name        = "${var.project_name}-${var.environment}-static-assets"
    Environment = var.environment
    Purpose     = "Static Assets"
  }
}

# IAM Role for EC2 instances (demo)
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-${var.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-role"
    Environment = var.environment
  }
}

# IAM Policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-${var.environment}-s3-access"
  description = "Policy for S3 access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_data.arn,
          "${aws_s3_bucket.app_data.arn}/*",
          aws_s3_bucket.static_assets.arn,
          "${aws_s3_bucket.static_assets.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.project_name}-${var.environment}-app-profile"
  role = aws_iam_role.app_role.name

  tags = {
    Environment = var.environment
  }
}

# Output values
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.demo.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}

output "s3_bucket_app_data" {
  description = "Name of the app data S3 bucket"
  value       = aws_s3_bucket.app_data.bucket
}

output "s3_bucket_static_assets" {
  description = "Name of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.app_role.arn
}

# Summary output for demo
output "localstack_demo_summary" {
  description = "Summary of LocalStack demo deployment"
  value = {
    vpc_cidr             = aws_vpc.demo.cidr_block
    public_subnets       = aws_subnet.public[*].cidr_block
    private_subnets      = aws_subnet.private[*].cidr_block
    s3_buckets           = [
      aws_s3_bucket.app_data.bucket,
      aws_s3_bucket.static_assets.bucket
    ]
    security_group       = aws_security_group.web.id
    log_group            = aws_cloudwatch_log_group.app_logs.name
    iam_role             = aws_iam_role.app_role.name
    deployment_note      = "LocalStack Community Edition - Free Tier Services Only"
    available_services   = "VPC, EC2, S3, IAM, CloudWatch Logs"
    missing_services     = "ECS, ELBv2, RDS (require LocalStack Pro)"
  }
}
