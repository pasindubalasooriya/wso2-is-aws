#!/usr/bin/env bash
# Demo B (CLI proof) — a REAL login through the IdP via the OAuth2 password
# grant with CORRECT credentials, then decode the returned ID token to show the
# claims really came from your WSO2 IS. A reliable, screenshot-able login proof
# that doesn't depend on browser cert-trust (unlike the SPA).
#
# Usage:
#   HOST=<alb-dns> CLIENT_ID=.. CLIENT_SECRET=.. USERNAME=victim PASSWORD=.. ./login-test.sh
set -euo pipefail

: "${HOST:?set HOST to the ALB DNS name}"
: "${CLIENT_ID:?set CLIENT_ID}"
: "${CLIENT_SECRET:?set CLIENT_SECRET}"
: "${USERNAME:?set USERNAME}"
: "${PASSWORD:?set PASSWORD}"

echo "==> Requesting tokens for ${USERNAME} ..."
RESP=$(curl -sk -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=password&username=${USERNAME}&password=${PASSWORD}&scope=openid" \
  "https://${HOST}/oauth2/token")

if ! echo "$RESP" | grep -q access_token; then
  echo "LOGIN FAILED:"; echo "$RESP"; exit 1
fi

ID_TOKEN=$(echo "$RESP" | sed -n 's/.*"id_token":"\([^"]*\)".*/\1/p')
echo "==> Login succeeded. ID token claims (from your IdP):"
# Decode the JWT payload (second segment), pad base64url, pretty-print.
echo "$ID_TOKEN" | cut -d. -f2 | tr '_-' '/+' | sed 's/$/===/' | base64 -d 2>/dev/null | jq . 2>/dev/null \
  || echo "$ID_TOKEN" | cut -d. -f2 | tr '_-' '/+' | sed 's/$/===/' | base64 -d 2>/dev/null
echo
echo "==> Calling /oauth2/userinfo with the access token:"
ACCESS=$(echo "$RESP" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
curl -sk -H "Authorization: Bearer ${ACCESS}" "https://${HOST}/oauth2/userinfo" | jq . 2>/dev/null || true
