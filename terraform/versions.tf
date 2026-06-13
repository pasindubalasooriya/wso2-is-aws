terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Remote state in S3 (bucket created by ../bootstrap).
  # Partial config: pass the account-specific bucket at init time, e.g.
  #   terraform init -backend-config="bucket=wso2is-tfstate-<ACCOUNT_ID>"
  backend "s3" {
    key          = "stack/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 state locking, no DynamoDB needed (TF >= 1.11)
  }
}
