output "dns_name" {
  value = aws_lb.this.dns_name
}

output "zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "alb_arn" {
  description = "ALB ARN (for WAF association)."
  value       = aws_lb.this.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN (Phase 6 attaches console-restriction rules)."
  value       = aws_lb_listener.https.arn
}

output "certificate_arn" {
  value = aws_acm_certificate.this.arn
}

output "alb_arn_suffix" {
  description = "For CloudWatch AWS/ApplicationELB dimensions."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "For CloudWatch target-group dimensions."
  value       = aws_lb_target_group.this.arn_suffix
}
