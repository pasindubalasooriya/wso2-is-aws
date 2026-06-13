#!/usr/bin/env bash
# Demo A — authorized credential-stuffing against YOUR OWN WSO2 IS.
# Hammers the OAuth2 password grant with wrong passwords for a victim user to
# generate failed-login audit events (and trip account lockout + the WAF rate
# rule + the CloudWatch failed-login alarm).
#
# ONLY run this against your own deployment. It's testing your own system.
#
# Usage:
#   HOST=<alb-dns> CLIENT_ID=.. CLIENT_SECRET=.. VICTIM=victim ./credential-stuffing.sh [attempts]
#
# Get an OAuth client by registering an app in the console (see apps/demo-spa/README.md)
# with the "Password" grant type enabled.
set -uo pipefail

: "${HOST:?set HOST to the ALB DNS name}"
: "${CLIENT_ID:?set CLIENT_ID}"
: "${CLIENT_SECRET:?set CLIENT_SECRET}"
: "${VICTIM:=victim}"
ATTEMPTS="${1:-60}"

echo "Target : https://${HOST}/oauth2/token"
echo "Victim : ${VICTIM}"
echo "Attempts: ${ATTEMPTS}"
echo "----------------------------------------"

ok=0; fail=0; locked=0
for i in $(seq 1 "$ATTEMPTS"); do
  WRONG="wrong-$(printf '%05d' "$i")-$RANDOM"
  RESP=$(curl -sk -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -d "grant_type=password&username=${VICTIM}&password=${WRONG}&scope=openid" \
    "https://${HOST}/oauth2/token")
  CODE=$(curl -sk -o /dev/null -w '%{http_code}' -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -d "grant_type=password&username=${VICTIM}&password=${WRONG}&scope=openid" \
    "https://${HOST}/oauth2/token")

  if echo "$RESP" | grep -qi "locked"; then
    locked=$((locked+1)); tag="LOCKED"
  elif echo "$RESP" | grep -qi "access_token"; then
    ok=$((ok+1)); tag="SUCCESS(!)"
  else
    fail=$((fail+1)); tag="denied"
  fi
  printf "[%03d] HTTP %s  %s\n" "$i" "$CODE" "$tag"
  sleep 0.2
done

echo "----------------------------------------"
echo "denied=${fail}  locked-responses=${locked}  success=${ok}"
echo "Now check: account-lock status, CloudWatch /wso2is/audit, the failed-login alarm, and (if WAF on) blocked requests."
