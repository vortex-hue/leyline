# ALB Module Outputs

output "arn" {
  description = "ARN of the Application Load Balancer"
  value       = var.enable_access_logs ? aws_lb.main_with_logging[0].arn : aws_lb.main.arn
}

output "arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  value       = var.enable_access_logs ? aws_lb.main_with_logging[0].arn_suffix : aws_lb.main.arn_suffix
}

output "dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.enable_access_logs ? aws_lb.main_with_logging[0].dns_name : aws_lb.main.dns_name
}

output "zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = var.enable_access_logs ? aws_lb.main_with_logging[0].zone_id : aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.main.name
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = var.certificate_arn != "" ? aws_lb_listener.http.arn : aws_lb_listener.http_fallback[0].arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
}

output "access_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = var.enable_access_logs ? aws_s3_bucket.alb_logs[0].id : null
}
