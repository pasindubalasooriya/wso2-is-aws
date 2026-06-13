variable "region" {
  description = "AWS region for the whole project."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for globally-unique resource names."
  type        = string
  default     = "wso2is"
}

variable "budget_notification_email" {
  description = "Email address that receives AWS Budgets credit-burn alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget ceiling (credit burn) in USD. Alerts fire at 25/50/80/100% of this."
  type        = number
  default     = 80
}
