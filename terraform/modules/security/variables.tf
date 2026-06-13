variable "name" {
  description = "Name prefix for tagging."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security groups in."
  type        = string
}
