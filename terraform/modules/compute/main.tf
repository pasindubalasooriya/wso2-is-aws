# ---------------------------------------------------------------------------
# Compute — AL2023 launch template + ASG for the WSO2 IS nodes.
# Config/scripts are delivered via S3 (re-upload on change); user-data is a stub.
# ---------------------------------------------------------------------------

# Admin credentials (kept out of code, like the DB creds).
resource "random_password" "admin" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "admin" {
  name                    = "${var.name}/admin"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id     = aws_secretsmanager_secret.admin.id
  secret_string = jsonencode({ username = "admin", password = random_password.admin.result })
}

# ----- Config/scripts → S3 (consumed by user-data + bootstrap) -----
locals {
  uploads = {
    "scripts/bootstrap.sh"        = "${path.root}/../scripts/bootstrap.sh"
    "scripts/init-db.sh"          = "${path.root}/../scripts/init-db.sh"
    "config/deployment.toml.tpl"  = "${path.root}/../config/deployment.toml.tpl"
    "config/wso2is.service"       = "${path.root}/../config/wso2is.service"
    "config/cw-agent-config.json" = "${path.root}/../config/cw-agent-config.json"
  }
}

resource "aws_s3_object" "artifacts" {
  for_each = local.uploads
  bucket   = var.artifacts_bucket
  key      = each.key
  source   = each.value
  etag     = filemd5(each.value)
}

# ----- AL2023 AMI -----
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ----- Launch template -----
resource "aws_launch_template" "node" {
  name_prefix   = "${var.name}-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.node.arn
  }

  vpc_security_group_ids = [var.is_node_sg_id]

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    artifacts_bucket  = var.artifacts_bucket
    db_secret_name    = var.db_secret_name
    admin_secret_name = aws_secretsmanager_secret.admin.name
    cluster_tag       = var.cluster_tag
    proxy_port        = var.proxy_port
    server_hostname   = var.server_hostname
    node_count        = var.node_count
    region            = var.region
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.name}-node"
      Cluster = var.cluster_tag # Hazelcast AWS membership discovery key
    }
  }

  # New user-data/config should roll fresh instances.
  update_default_version = true
}

# ----- Auto Scaling Group -----
resource "aws_autoscaling_group" "nodes" {
  name                = "${var.name}-asg"
  desired_capacity    = var.node_count
  min_size            = var.node_count
  max_size            = var.node_count
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  health_check_type         = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = 600 # IS startup is slow on t3.medium

  launch_template {
    id = aws_launch_template.node.id
    # Use the concrete latest version (not "$Latest") so a launch-template
    # change shows a diff here and triggers the instance refresh below.
    version = aws_launch_template.node.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0 # lab: allow full replace (only 1-2 nodes)
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-node"
    propagate_at_launch = true
  }
}
