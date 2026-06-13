output "asg_name" {
  value = aws_autoscaling_group.nodes.name
}

output "launch_template_id" {
  value = aws_launch_template.node.id
}

output "instance_profile_arn" {
  value = aws_iam_instance_profile.node.arn
}

output "admin_secret_name" {
  description = "Secrets Manager secret holding the IS admin credentials."
  value       = aws_secretsmanager_secret.admin.name
}

output "cluster_tag" {
  value = var.cluster_tag
}
