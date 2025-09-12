# Terraform Provider Configuration for LocalStack Demo

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = "test"
  secret_key = "test"
  
  # LocalStack endpoints
  endpoints {
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    ecs            = "http://localhost:4566"
    elbv2          = "http://localhost:4566"
    iam            = "http://localhost:4566"
    logs           = "http://localhost:4566"
    s3             = "http://localhost:4566"
    sts            = "http://localhost:4566"
  }
  
  # LocalStack configuration
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style          = true
  
  default_tags {
    tags = {
      Project     = "LeyLine-DNS-Service"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Demo        = "LocalStack"
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}
