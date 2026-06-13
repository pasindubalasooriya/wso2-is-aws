variable "name" {
  description = "Name prefix."
  type        = string
}

variable "alb_arn" {
  description = "ARN of the ALB to protect."
  type        = string
}

variable "rate_limit" {
  description = "Max requests per 5-minute window per source IP before blocking."
  type        = number
  default     = 100
}
