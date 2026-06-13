output "state_bucket" {
  description = "S3 bucket name for Terraform remote state. Put this in ../terraform/backend.tf."
  value       = aws_s3_bucket.tfstate.id
}

output "artifacts_bucket" {
  description = "S3 bucket name for cached IS/Corretto artifacts."
  value       = aws_s3_bucket.artifacts.id
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "backend_config_hint" {
  description = "Copy these values into ../terraform/backend.tf."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.tfstate.id}"
    key          = "stack/terraform.tfstate"
    region       = "${var.region}"
    encrypt      = true
    use_lockfile = true
  EOT
}
