#!/usr/bin/env bash
# Stage install artifacts into the S3 artifacts bucket (Phase 0.4).
# Usage: bash scripts/stage-artifacts.sh <artifacts-bucket-name>
# Requires: aws CLI with AWS_PROFILE set, curl.
set -euo pipefail

BUCKET="${1:?Usage: stage-artifacts.sh <artifacts-bucket-name>}"

# --- Versions (verify these URLs against the WSO2 / Corretto sites) ---
IS_VERSION="7.3.0"
IS_ZIP="wso2is-${IS_VERSION}.zip"
IS_URL="https://github.com/wso2/product-is/releases/download/v${IS_VERSION}/${IS_ZIP}"

CORRETTO_RPM="amazon-corretto-21-x64-linux-jdk.rpm"
CORRETTO_URL="https://corretto.aws/downloads/latest/${CORRETTO_RPM}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading WSO2 IS ${IS_VERSION} ..."
curl -fL --retry 3 -o "${TMP}/${IS_ZIP}" "${IS_URL}"

echo "==> Downloading Amazon Corretto 21 ..."
curl -fL --retry 3 -o "${TMP}/${CORRETTO_RPM}" "${CORRETTO_URL}"

echo "==> Uploading to s3://${BUCKET}/ ..."
aws s3 cp "${TMP}/${IS_ZIP}"       "s3://${BUCKET}/${IS_ZIP}"
aws s3 cp "${TMP}/${CORRETTO_RPM}" "s3://${BUCKET}/${CORRETTO_RPM}"

echo "==> Done. Bucket contents:"
aws s3 ls "s3://${BUCKET}/"
