terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap uses LOCAL state on purpose: it creates the very bucket that the
  # main stack later uses as its remote backend (chicken-and-egg). Keep the
  # local bootstrap state file out of git (see .gitignore).
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "wso2-is-aws"
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}
