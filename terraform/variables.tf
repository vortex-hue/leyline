# LeyLine DNS Service - LocalStack Demo Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "leyline"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "aws_region" {
  description = "AWS region (LocalStack demo)"
  type        = string
  default     = "us-east-1"
}

variable "ecs_cpu" {
  description = "CPU units for ECS task"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 1024
}

variable "container_image_uri" {
  description = "URI of the container image"
  type        = string
  default     = "leyline-api:latest"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}