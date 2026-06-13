# ----- Phase 1: Network -----
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  value = module.vpc.private_db_subnet_ids
}

output "nat_public_ip" {
  description = "Stable public egress IP of the cluster."
  value       = module.vpc.nat_public_ip
}

output "alb_sg_id" {
  value = module.security.alb_sg_id
}

output "is_node_sg_id" {
  value = module.security.is_node_sg_id
}

output "rds_sg_id" {
  value = module.security.rds_sg_id
}

# ----- Phase 2: Database -----
output "rds_endpoint" {
  value = module.rds.endpoint
}

output "db_secret_name" {
  description = "Secrets Manager secret holding DB credentials."
  value       = module.rds.secret_name
}

output "identity_db_name" {
  value = module.rds.identity_db_name
}

output "shared_db_name" {
  value = module.rds.shared_db_name
}

# ----- Phase 3: Compute -----
output "asg_name" {
  value = module.compute.asg_name
}

output "admin_secret_name" {
  description = "Secrets Manager secret holding IS admin credentials."
  value       = module.compute.admin_secret_name
}

# ----- Phase 4: ALB -----
output "alb_dns_name" {
  description = "Public DNS of the load balancer — the IdP entry point."
  value       = module.alb.dns_name
}

output "console_url" {
  value = "https://${module.alb.dns_name}/console"
}

# ----- Phase 5: Observability -----
output "dashboard_name" {
  value = module.observability.dashboard_name
}

output "log_groups" {
  value = module.observability.log_group_names
}
