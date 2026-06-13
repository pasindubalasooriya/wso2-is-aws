output "endpoint" {
  description = "RDS endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "instance_id" {
  description = "RDS DB instance identifier (for CloudWatch dimensions)."
  value       = aws_db_instance.this.identifier
}

output "address" {
  description = "RDS hostname."
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "secret_arn" {
  description = "Secrets Manager ARN holding DB credentials + connection info."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.db.name
}

output "identity_db_name" {
  value = local.identity_db
}

output "shared_db_name" {
  value = local.shared_db
}
