# ---------------------------------------------------------------------------
# Observability — log groups for the CloudWatch agent to ship into, metric
# filters that turn log patterns into alarms, an SNS email topic, and a
# dashboard. (Plan §7.)
# ---------------------------------------------------------------------------

locals {
  lg_carbon = "/wso2is/carbon"
  lg_audit  = "/wso2is/audit"
  lg_http   = "/wso2is/http-access"
  metric_ns = "WSO2IS/Logs"
}

# ----- Log groups (created here so the agent ships into existing groups and
#       retention is managed as code) -----
resource "aws_cloudwatch_log_group" "carbon" {
  name              = local.lg_carbon
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "audit" {
  name              = local.lg_audit
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "http" {
  name              = local.lg_http
  retention_in_days = var.log_retention_days
}

# ----- SNS topic + email subscription -----
resource "aws_sns_topic" "alarms" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ----- Metric filters: turn log patterns into numbers -----
resource "aws_cloudwatch_log_metric_filter" "errors" {
  name           = "${var.name}-carbon-errors"
  log_group_name = aws_cloudwatch_log_group.carbon.name
  pattern        = "ERROR"

  metric_transformation {
    name          = "CarbonErrors"
    namespace     = local.metric_ns
    value         = "1"
    default_value = "0"
  }
}

# Failed password-grant logins. WSO2's PasswordGrantAuditLogger records every
# attempt; a FAILURE has "AuthenticatedUser" : "N/A" (a success has the real
# username). Calibrated against real attack traffic in Phase 8 via
# `aws logs test-metric-filter`.
resource "aws_cloudwatch_log_metric_filter" "failed_logins" {
  name           = "${var.name}-failed-logins"
  log_group_name = aws_cloudwatch_log_group.audit.name
  pattern        = "\"\\\"AuthenticatedUser\\\" : \\\"N/A\\\"\""

  metric_transformation {
    name          = "FailedLogins"
    namespace     = local.metric_ns
    value         = "1"
    default_value = "0"
  }
}

# ----- Alarms -----
resource "aws_cloudwatch_metric_alarm" "error_spike" {
  alarm_name          = "${var.name}-error-spike"
  alarm_description   = "More than 10 ERROR lines in the carbon log within 5 minutes."
  namespace           = local.metric_ns
  metric_name         = "CarbonErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "failed_logins" {
  alarm_name          = "${var.name}-failed-logins"
  alarm_description   = "More than 20 failed logins in 5 minutes (brute-force signal)."
  namespace           = local.metric_ns
  metric_name         = "FailedLogins"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 20
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  alarm_description   = "ALB returning 5xx errors."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${var.name}-unhealthy-hosts"
  alarm_description   = "At least one IS node unhealthy behind the ALB."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }
  alarm_actions = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.name}-rds-cpu"
  alarm_description   = "RDS CPU above 80%."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { DBInstanceIdentifier = var.rds_instance_id }
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

# ----- Dashboard -----
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB requests & 5xx"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { stat = "Sum" }]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Healthy / Unhealthy targets"
          region = var.region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.target_group_arn_suffix, { stat = "Average" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6
        properties = {
          title   = "Node memory %"
          region  = var.region
          view    = "timeSeries"
          metrics = [["WSO2IS", "mem_used_percent", { stat = "Average" }]]
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6
        properties = {
          title   = "RDS CPU %"
          region  = var.region
          view    = "timeSeries"
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id, { stat = "Average" }]]
        }
      },
      {
        type = "metric", x = 16, y = 6, width = 8, height = 6
        properties = {
          title  = "Failed logins & errors"
          region = var.region
          view   = "timeSeries"
          metrics = [
            [local.metric_ns, "FailedLogins", { stat = "Sum" }],
            [local.metric_ns, "CarbonErrors", { stat = "Sum" }]
          ]
        }
      },
      {
        type = "log", x = 0, y = 12, width = 24, height = 6
        properties = {
          title  = "Audit log — recent events"
          region = var.region
          query  = "SOURCE '${local.lg_audit}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}
