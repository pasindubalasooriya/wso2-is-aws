variable "name" {
  description = "Name prefix."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "subnet_ids" {
  description = "Private app subnet IDs (one node per AZ when scaled)."
  type        = list(string)
}

variable "is_node_sg_id" {
  description = "Security group for IS nodes."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.medium"
}

variable "node_count" {
  description = "Desired number of IS nodes (1 for Phase 3, 2 for Phase 4)."
  type        = number
  default     = 1
}

variable "artifacts_bucket" {
  description = "S3 bucket with cached IS/Corretto + config/scripts."
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the DB credentials secret."
  type        = string
}

variable "db_secret_name" {
  description = "Name of the DB credentials secret."
  type        = string
}

variable "cluster_tag" {
  description = "Value of the Cluster tag used by AWS Hazelcast membership discovery."
  type        = string
  default     = "wso2is"
}

variable "proxy_port" {
  description = "Port IS advertises (9443 direct in Phase 3; 443 behind ALB in Phase 4)."
  type        = number
  default     = 9443
}

variable "server_hostname" {
  description = "Hostname IS advertises (ALB DNS in Phase 4). Empty = use the node's private IP."
  type        = string
  default     = ""
}

variable "target_group_arns" {
  description = "ALB target group ARNs to attach the ASG to (empty until Phase 4)."
  type        = list(string)
  default     = []
}
