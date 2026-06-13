# CloudWatch Logs Insights — reusable queries

Run these in **CloudWatch → Logs Insights**, selecting the relevant log group.

## Failed logins by user (audit log)
Log group: `/wso2is/audit`
```
fields @timestamp, @message
| filter @message like /Failed|Failure|failed/
| parse @message /Subject : (?<user>[^\|,]+)/
| stats count(*) as failures by user
| sort failures desc
```

## Authentication events over time (audit log)
```
fields @timestamp, @message
| filter @message like /authentication|Login/
| stats count(*) as events by bin(1m)
```

## Errors in the carbon log
Log group: `/wso2is/carbon`
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

## Top client IPs hitting the login endpoint (access log)
Log group: `/wso2is/http-access`
```
fields @timestamp, @message
| filter @message like /oauth2\/token|authenticationendpoint/
| parse @message /^(?<ip>\S+)/
| stats count(*) as hits by ip
| sort hits desc
```

## During the attack — failures per minute (shows the burst)
Log group: `/wso2is/audit`
```
fields @timestamp
| filter @message like /Failed|Failure/
| stats count(*) as failed by bin(1m)
| sort @timestamp desc
```

> Note: the exact field names in WSO2 audit lines (Subject / Initiator / Result)
> should be confirmed against a real failed-login entry during the demo, then the
> `parse` patterns above tightened to match.
