# Stack modules

Built phase by phase (see plan §10). Each is wired into `../main.tf` when its phase begins.

| Module | Phase | Purpose |
|---|---|---|
| `vpc` | 1 | VPC, 6 subnets, IGW, NAT, route tables, NACLs, S3 gateway endpoint, flow logs |
| `security` | 1 | Security groups |
| `rds` | 2 | DB subnet group, parameter group, MySQL 8 instance |
| `compute` | 3–4 | Launch template, ASG, IAM instance profile |
| `alb` | 4 | ALB, listener + console-restriction rules, target group, optional WAF |
| `observability` | 5 | Log groups, metric filters, alarms, SNS, dashboard |
| `secrets` | 6 | Secrets Manager entries |
