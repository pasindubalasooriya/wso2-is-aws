variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "lab"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "wso2is"
}

variable "artifacts_bucket" {
  description = "S3 bucket holding the cached IS 7.3 zip and Corretto 21 (output from bootstrap)."
  type        = string
}

# ----- Networking -----
variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to span (project is designed for 2)."
  type        = number
  default     = 2
}

# ----- Compute -----
variable "is_instance_type" {
  description = <<-EOT
    EC2 instance type for WSO2 IS nodes. The AWS Free plan restricts EC2 to
    free-tier-eligible types, so t3.medium is NOT allowed. Eligible options with
    enough RAM: c7i-flex.large (4 GB, the IS minimum) or m7i-flex.large (8 GB).
  EOT
  type        = string
  default     = "m7i-flex.large"
}

variable "is_node_count" {
  description = "Number of IS nodes. 1 for Phase 3 (single node), 2 for Phase 4 (HA cluster)."
  type        = number
  default     = 1
}

variable "is_proxy_port" {
  description = "Port IS advertises. 9443 for direct access (Phase 3); 443 behind the ALB (Phase 4)."
  type        = number
  default     = 9443
}

# ----- Database -----
variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Enable RDS Multi-AZ. Keep false for normal sessions; flip true for the failover-test session."
  type        = bool
  default     = false
}

# ----- Pause/resume with data preservation -----
variable "db_skip_final_snapshot" {
  description = "If false, terraform destroy snapshots the DB first (also set db_final_snapshot_identifier)."
  type        = bool
  default     = true
}

variable "db_final_snapshot_identifier" {
  description = "Unique name for the destroy-time snapshot (when db_skip_final_snapshot=false)."
  type        = string
  default     = null
}

variable "db_snapshot_identifier" {
  description = "Restore the DB from this snapshot on apply. Empty = fresh DB."
  type        = string
  default     = null
}

# ----- Access control -----
variable "admin_cidr" {
  description = "Your public IP (CIDR /32) allowed to reach the admin console paths."
  type        = string
}

# ----- Feature toggles (cost control) -----
variable "enable_waf" {
  description = "Attach AWS WAF to the ALB. Enable for hardening / attack-demo sessions only."
  type        = bool
  default     = false
}

variable "alarm_email" {
  description = "Email for CloudWatch alarm notifications (confirm the SNS subscription via the emailed link)."
  type        = string
}
