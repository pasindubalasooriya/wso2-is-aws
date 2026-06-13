output "sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "log_group_names" {
  value = [
    aws_cloudwatch_log_group.carbon.name,
    aws_cloudwatch_log_group.audit.name,
    aws_cloudwatch_log_group.http.name,
  ]
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}
