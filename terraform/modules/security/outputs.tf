output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "is_node_sg_id" {
  value = aws_security_group.is_node.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}
