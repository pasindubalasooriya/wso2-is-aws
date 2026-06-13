# ---------------------------------------------------------------------------
# ALB module — internet-facing HTTPS load balancer for the IS cluster (plan §4).
# Self-signed cert imported into ACM (free placeholder; swap for a real
# DNS-validated cert + domain later). Target group does HTTPS to the nodes
# with session stickiness and the IS health-check endpoint.
# ---------------------------------------------------------------------------

# ----- Self-signed cert → ACM -----
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name  = var.cert_common_name
    organization = "wso2-is-aws (lab)"
  }

  dns_names             = [var.cert_common_name]
  validity_period_hours = 8760 # 1 year
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "this" {
  private_key      = tls_private_key.this.private_key_pem
  certificate_body = tls_self_signed_cert.this.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

# ----- Load balancer -----
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  idle_timeout = 120 # long-polling auth flows
  tags         = { Name = "${var.name}-alb" }
}

# ----- Target group (HTTPS to nodes, sticky, IS health check) -----
resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 60

  health_check {
    protocol            = "HTTPS"
    path                = var.health_check_path
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = var.stickiness_seconds
    enabled         = true
  }

  tags = { Name = "${var.name}-tg" }
}

# ----- Listeners -----
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.this.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# ----- Admin console restriction (plan §3.4) -----
# Higher priority (lower number) wins. Admin IP to an admin path → forward;
# anyone else to an admin path → 403. Login/OIDC/SCIM stay public (default action).
resource "aws_lb_listener_rule" "console_admin" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern { values = var.admin_paths }
  }
  condition {
    source_ip { values = [var.admin_cidr] }
  }
}

resource "aws_lb_listener_rule" "console_block" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden: admin console is restricted."
      status_code  = "403"
    }
  }

  condition {
    path_pattern { values = var.admin_paths }
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
