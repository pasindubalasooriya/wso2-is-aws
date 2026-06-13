provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "wso2-is-aws"
      ManagedBy = "terraform"
      Env       = var.environment
    }
  }
}
