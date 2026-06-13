variable "name" {
  description = "Name prefix."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group for the ALB."
  type        = string
}

variable "target_port" {
  description = "Port the IS nodes listen on."
  type        = number
  default     = 9443
}

variable "health_check_path" {
  description = "IS health-check endpoint."
  type        = string
  default     = "/api/health-check/v1.0/health"
}

variable "cert_common_name" {
  description = "CN/SAN for the self-signed cert (placeholder until a real domain + ACM)."
  type        = string
  default     = "is.example.internal"
}

variable "stickiness_seconds" {
  description = "ALB-cookie session stickiness duration."
  type        = number
  default     = 3600
}

variable "admin_cidr" {
  description = "CIDR allowed to reach the admin console paths; everyone else gets 403."
  type        = string
}

variable "admin_paths" {
  description = "Path patterns treated as admin-only."
  type        = list(string)
  default     = ["/console*", "/carbon*", "/api/server/*"]
}
