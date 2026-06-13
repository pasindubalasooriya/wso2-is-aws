# WSO2 Identity Server 7.3 on AWS - Reference architecture

Highly available **WSO2 Identity Server 7.3** on AWS across 2 Availability Zones  defined entirely in Terraform, built to run on the **AWS Free plan (credit-based)** with `$0` out of pocket.


## Proven (verified live)

- ✅ 2-node WSO2 IS cluster across 2 AZs behind an HTTPS ALB, both targets healthy, single Hazelcast cluster
- ✅ Real OIDC login issues a valid token from the IdP
- ✅ Survives a node kill - logins continue on the survivor, ASG auto-replaces the dead node
- ✅ Defends itself - account lockout + CloudWatch failed-login alarm (email) + WAF rate-limit (121 reqs blocked) all caught a credential-stuffing attack
- ✅ Admin console returns 403 to the public internet, 200 from the admin IP

## What this builds

- VPC across 2 AZs (public / private-app / private-db subnet tiers), single NAT, free S3 gateway endpoint
- 2× EC2 WSO2 IS 7.3 nodes (one per AZ), clustered, fronted by an HTTPS ALB
- RDS MySQL 8 (single-AZ default, `multi_az` togglable for failover tests)
- CloudWatch logs/metrics/alarms, Secrets Manager, optional WAF
- Admin console restricted from the public internet

## Layout

```
bootstrap/    one-time: S3 state bucket, artifacts bucket, budget alarms (local state)
terraform/    the stack - root config + modules/ (built phase by phase)
config/       deployment.toml template, CloudWatch agent config, systemd unit
scripts/      EC2 bootstrap, DB init, demo attack script
apps/         demo OIDC SPA (Demo B)
docs/         architecture, ADRs, demo writeups, screenshots
```

## Cost discipline

The environment is **ephemeral**: `terraform apply` per work session, `terraform destroy` at the end of every session. See the plan's §0 and §12.

## Getting started

1. Setting up account and guardrails.
2. `cd bootstrap && terraform init && terraform apply` - creates state + artifacts buckets and budget alarms.
3. Stage the IS 7.3 zip and Corretto 21 into the artifacts bucket (script in `scripts/`).
4. `cd ../terraform` and init with your account-specific state bucket (the backend uses partial config so no account ID is committed):
   ```
   terraform init -backend-config="bucket=wso2is-tfstate-<ACCOUNT_ID>"
   ```
   Then copy `terraform.tfvars.example` → `terraform.tfvars`, fill in your values, and `terraform apply`.
5. Subsequent phases build out `terraform/modules/`.

## Status

| Phase | State |
|---|---|
| 0 — Account & guardrails | ✅ |
| 1 — Network | ✅ |
| 2 — Database | ✅ |
| 3 — Single node | ✅ |
| 4 — HA cluster | ✅ |
| 5 — Observability | ✅ |
| 6 — Hardening | ✅ |
| 7 — Demo apps | ✅ |

## Modules

| Module | Purpose |
|---|---|
| `vpc` | VPC, 6 subnets (3 tiers × 2 AZs), IGW, single NAT, route tables, NACLs, S3 gateway endpoint, flow logs |
| `security` | Security groups (ALB / IS node / RDS), least-privilege egress |
| `rds` | MySQL 8, Secrets Manager creds, snapshot/restore vars |
| `compute` | AL2023 launch template (IMDSv2), ASG, IAM instance profile, S3-delivered config/scripts |
| `alb` | HTTPS ALB, self-signed ACM cert, target group (sticky + health check), console-restriction rules |
| `observability` | Log groups, metric filters, alarms, SNS email, dashboard |
| `waf` | WAFv2 web ACL (managed rules + rate limit), behind `enable_waf` |
