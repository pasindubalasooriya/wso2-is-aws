# ---------------------------------------------------------------------------
# RDS MySQL 8 — shared database for the WSO2 IS cluster (plan §6).
# Private, encrypted, reachable only from the app tier. Credentials live in
# Secrets Manager; the two logical DBs + app user are created in Phase 3
# (init-db) because that needs in-VPC access and the IS dbscripts.
# ---------------------------------------------------------------------------

locals {
  identity_db = "WSO2_IDENTITY_DB"
  shared_db   = "WSO2_SHARED_DB"
}

# ----- Credentials -----
resource "random_password" "master" {
  length  = 24
  special = false # avoid RDS-disallowed chars (/, @, ", space)
}

resource "random_password" "app" {
  length  = 24
  special = false
}

# ----- Subnet + parameter groups -----
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.db_subnet_ids
  tags       = { Name = "${var.name}-db-subnet-group" }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-mysql8"
  family = "mysql8.0"

  # WSO2 stored functions/procedures need this on RDS (no SUPER privilege).
  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ----- Instance -----
resource "aws_db_instance" "this" {
  identifier     = "${var.name}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = var.backup_retention_period
  apply_immediately       = true

  # No initial db_name — both logical DBs are created with explicit charset
  # during init-db.
  deletion_protection = false

  # Pause/resume: optionally snapshot on destroy and restore on apply.
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
  snapshot_identifier       = var.snapshot_identifier

  tags = { Name = "${var.name}-mysql" }
}

# ----- Secrets Manager: one secret with full connection detail -----
resource "aws_secretsmanager_secret" "db" {
  name = "${var.name}/db"
  # recovery_window_in_days = 0 lets an ephemeral destroy/apply reuse the name
  # immediately instead of waiting out the 7-day soft-delete window.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host            = aws_db_instance.this.address
    port            = aws_db_instance.this.port
    master_username = var.master_username
    master_password = random_password.master.result
    app_username    = var.app_username
    app_password    = random_password.app.result
    identity_db     = local.identity_db
    shared_db       = local.shared_db
  })
}
