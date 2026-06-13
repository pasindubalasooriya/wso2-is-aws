variable "name" {
  description = "Name prefix."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for the IS log groups."
  type        = number
  default     = 30
}

variable "alarm_email" {
  description = "Email subscribed to the alarm SNS topic (must be confirmed via the email link)."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (e.g. app/wso2is-alb/abc) for CloudWatch dimensions."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch dimensions."
  type        = string
}

variable "rds_instance_id" {
  description = "RDS DB instance identifier for CloudWatch dimensions."
  type        = string
}

variable "region" {
  description = "AWS region (for the dashboard)."
  type        = string
}
