# ---------------------------------------------------------------------------
# Root module — wires together the stack modules.
# Modules are added phase by phase (see ../../wso2-is-aws-deployment-plan.md §10).
# ---------------------------------------------------------------------------

# Phase 1 — Network
module "vpc" {
  source   = "./modules/vpc"
  name     = var.name_prefix
  vpc_cidr = var.vpc_cidr
  az_count = var.az_count
}

# Phase 1 — Security groups
module "security" {
  source = "./modules/security"
  name   = var.name_prefix
  vpc_id = module.vpc.vpc_id
}

# Phase 2 — Database
module "rds" {
  source                    = "./modules/rds"
  name                      = var.name_prefix
  db_subnet_ids             = module.vpc.private_db_subnet_ids
  vpc_security_group_ids    = [module.security.rds_sg_id]
  instance_class            = var.db_instance_class
  multi_az                  = var.db_multi_az
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_final_snapshot_identifier
  snapshot_identifier       = var.db_snapshot_identifier
}

# Phase 3-4 — Compute (launch template + ASG)
module "compute" {
  source            = "./modules/compute"
  name              = var.name_prefix
  region            = var.region
  subnet_ids        = module.vpc.private_app_subnet_ids
  is_node_sg_id     = module.security.is_node_sg_id
  instance_type     = var.is_instance_type
  node_count        = var.is_node_count
  proxy_port        = var.is_proxy_port
  server_hostname   = module.alb.dns_name
  target_group_arns = [module.alb.target_group_arn]
  artifacts_bucket  = var.artifacts_bucket
  db_secret_arn     = module.rds.secret_arn
  db_secret_name    = module.rds.secret_name

  # Log groups must exist before the agent on a node starts shipping to them.
  depends_on = [module.observability]
}

# Phase 4 — ALB (Phase 6 adds console restriction via admin_cidr)
module "alb" {
  source            = "./modules/alb"
  name              = var.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  admin_cidr        = var.admin_cidr
}

# Phase 6 — WAF (only when enable_waf=true)
module "waf" {
  count   = var.enable_waf ? 1 : 0
  source  = "./modules/waf"
  name    = var.name_prefix
  alb_arn = module.alb.alb_arn
}

# Phase 5 — Observability
module "observability" {
  source                  = "./modules/observability"
  name                    = var.name_prefix
  region                  = var.region
  alarm_email             = var.alarm_email
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  rds_instance_id         = module.rds.instance_id
}

# Phase 4 — ALB (+ WAF when enable_waf)
# module "alb" { source = "./modules/alb" ... }

# Phase 5 — Observability
# module "observability" { source = "./modules/observability" ... }

# Phase 6 — Secrets
# module "secrets" { source = "./modules/secrets" ... }
