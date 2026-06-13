# ---------------------------------------------------------------------------
# VPC module — 2-AZ network with three subnet tiers (public / app / db),
# single NAT, free S3 gateway endpoint, coarse per-tier NACLs, and flow logs.
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Subnet layout (matches plan §2):
  #   public      10.0.0.0/24, 10.0.1.0/24
  #   private-app 10.0.10.0/24, 10.0.11.0/24
  #   private-db  10.0.20.0/24, 10.0.21.0/24
  public_cidrs      = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_app_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 10 + i)]
  private_db_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, 20 + i)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

# ----- Subnets -----
resource "aws_subnet" "public" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name}-public-${count.index}", Tier = "public" }
}

resource "aws_subnet" "private_app" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_app_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name}-app-${count.index}", Tier = "private-app" }
}

resource "aws_subnet" "private_db" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_db_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name}-db-${count.index}", Tier = "private-db" }
}

# ----- Internet Gateway + single NAT -----
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

# Single NAT in the first public subnet (cost trade-off — see plan §2).
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

# ----- Route tables -----
# Public: → IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private app: → NAT (outbound internet for bootstrap, AWS APIs)
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-rt-app" }
}

resource "aws_route" "app_nat" {
  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private_app" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app.id
}

# Private db: no internet route at all (DB never egresses to the internet).
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-rt-db" }
}

resource "aws_route_table_association" "private_db" {
  count          = var.az_count
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db.id
}

# ----- S3 gateway endpoint (free) for the artifact cache without NAT charges -----
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_app.id, aws_route_table.private_db.id]
  tags              = { Name = "${var.name}-vpce-s3" }
}

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Network ACLs — coarse per-tier isolation (SGs do the fine-grained work).
# NACLs are stateless, so ephemeral return ranges are explicit.
# ---------------------------------------------------------------------------

# Public: internet 443/80 + ephemeral return; all intra-VPC; all egress.
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.public[*].id
  tags       = { Name = "${var.name}-nacl-public" }
}

resource "aws_network_acl_rule" "public_in" {
  for_each = {
    100 = { proto = "tcp", from = 443, to = 443, cidr = "0.0.0.0/0" }
    110 = { proto = "tcp", from = 80, to = 80, cidr = "0.0.0.0/0" }
    120 = { proto = "tcp", from = 1024, to = 65535, cidr = "0.0.0.0/0" } # return traffic
    130 = { proto = "tcp", from = 0, to = 65535, cidr = var.vpc_cidr }   # intra-VPC (ALB↔targets, NAT)
  }
  network_acl_id = aws_network_acl.public.id
  rule_number    = each.key
  egress         = false
  protocol       = each.value.proto
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}

resource "aws_network_acl_rule" "public_out" {
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Private app: all intra-VPC in; ephemeral return from internet (via NAT); all egress.
resource "aws_network_acl" "private_app" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private_app[*].id
  tags       = { Name = "${var.name}-nacl-app" }
}

resource "aws_network_acl_rule" "app_in" {
  for_each = {
    100 = { from = 0, to = 65535, cidr = var.vpc_cidr }   # intra-VPC (ALB, clustering, DB return)
    110 = { from = 1024, to = 65535, cidr = "0.0.0.0/0" } # NAT return traffic
  }
  network_acl_id = aws_network_acl.private_app.id
  rule_number    = each.key
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr
  from_port      = each.value.from
  to_port        = each.value.to
}

resource "aws_network_acl_rule" "app_out" {
  network_acl_id = aws_network_acl.private_app.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Private db: ONLY the app tier may reach it; egress confined to the VPC. No internet.
resource "aws_network_acl" "private_db" {
  vpc_id     = aws_vpc.this.id
  subnet_ids = aws_subnet.private_db[*].id
  tags       = { Name = "${var.name}-nacl-db" }
}

resource "aws_network_acl_rule" "db_in" {
  count          = var.az_count
  network_acl_id = aws_network_acl.private_db.id
  rule_number    = 100 + count.index
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.private_app_cidrs[count.index]
  from_port      = 3306
  to_port        = 3306
}

resource "aws_network_acl_rule" "db_in_ephemeral" {
  count          = var.az_count
  network_acl_id = aws_network_acl.private_db.id
  rule_number    = 200 + count.index
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = local.private_app_cidrs[count.index]
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "db_out" {
  network_acl_id = aws_network_acl.private_db.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = var.vpc_cidr
  from_port      = 0
  to_port        = 65535
}

# ---------------------------------------------------------------------------
# VPC Flow Logs → CloudWatch (network forensics; pairs with the NACL story)
# ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/wso2is/vpc-flow-logs"
  retention_in_days = var.flow_log_retention_days
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "${var.name}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

data "aws_iam_policy_document" "flow_perms" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "${var.name}-flow-logs"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_perms.json
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow.arn
  iam_role_arn    = aws_iam_role.flow.arn
  tags            = { Name = "${var.name}-flow-log" }
}
