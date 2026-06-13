# ---------------------------------------------------------------------------
# Security groups — the stateful firewall layer (plan §3.1).
# Rules are separate resources to avoid circular dependencies between SGs.
# ---------------------------------------------------------------------------

# ----- ALB: public HTTPS entry -----
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB: public HTTPS in, forward to IS nodes"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet (redirect to HTTPS)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_nodes" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to IS nodes on 9443"
  ip_protocol                  = "tcp"
  from_port                    = 9443
  to_port                      = 9443
  referenced_security_group_id = aws_security_group.is_node.id
}

# ----- IS nodes -----
resource "aws_security_group" "is_node" {
  name        = "${var.name}-is-node-sg"
  description = "WSO2 IS nodes: ALB traffic + cluster gossip; egress for bootstrap/DB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-is-node-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "node_from_alb" {
  security_group_id            = aws_security_group.is_node.id
  description                  = "App traffic from ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 9443
  to_port                      = 9443
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "node_cluster" {
  security_group_id            = aws_security_group.is_node.id
  description                  = "Hazelcast clustering between IS nodes"
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
  referenced_security_group_id = aws_security_group.is_node.id
}

# Least-privilege egress (Phase 6). Covers everything the node actually needs:
# HTTPS to AWS APIs/S3/SSM/CloudWatch + package/maven downloads, HTTP for dnf
# mirrors, DNS, MySQL to RDS, and Hazelcast clustering to peers.
resource "aws_vpc_security_group_egress_rule" "node_https" {
  security_group_id = aws_security_group.is_node.id
  description       = "HTTPS out (AWS APIs, S3, SSM, CloudWatch, maven)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "node_http" {
  security_group_id = aws_security_group.is_node.id
  description       = "HTTP out (dnf package mirrors)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "node_dns_udp" {
  security_group_id = aws_security_group.is_node.id
  description       = "DNS (UDP)"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "node_dns_tcp" {
  security_group_id = aws_security_group.is_node.id
  description       = "DNS (TCP)"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "node_to_rds" {
  security_group_id            = aws_security_group.is_node.id
  description                  = "MySQL to RDS"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_egress_rule" "node_cluster" {
  security_group_id            = aws_security_group.is_node.id
  description                  = "Hazelcast clustering to peers"
  ip_protocol                  = "tcp"
  from_port                    = 4000
  to_port                      = 4000
  referenced_security_group_id = aws_security_group.is_node.id
}

# ----- RDS -----
resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS MySQL: 3306 from IS nodes only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from IS nodes only"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.is_node.id
}
