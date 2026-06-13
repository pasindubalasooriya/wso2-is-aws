variable "name" {
  description = "Name prefix for tagging."
  type        = string
}

variable "db_subnet_ids" {
  description = "Private DB subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "Security groups for the RDS instance (rds-sg)."
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "allocated_storage" {
  description = "Storage in GB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ (flip true for the failover-test session)."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Automated backup retention in days."
  type        = number
  default     = 1
}

variable "master_username" {
  description = "RDS master username."
  type        = string
  default     = "wso2admin"
}

variable "app_username" {
  description = "Application DB user that WSO2 IS connects as (created during Phase 3 init-db)."
  type        = string
  default     = "wso2is"
}

# ----- Pause/resume with data preservation -----
variable "skip_final_snapshot" {
  description = "If false, terraform destroy takes a final snapshot first (set final_snapshot_identifier too)."
  type        = bool
  default     = true
}

variable "final_snapshot_identifier" {
  description = "Name for the snapshot taken on destroy (required, and must be unique, when skip_final_snapshot=false)."
  type        = string
  default     = null
}

variable "snapshot_identifier" {
  description = "Restore the DB from this snapshot on apply. Empty = fresh empty DB. Setting this on a running DB replaces it."
  type        = string
  default     = null
}
