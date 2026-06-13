#!/usr/bin/env bash
# DB init — safe to run on every node boot and concurrently across nodes.
#   * Databases + app user: idempotent (CREATE ... IF NOT EXISTS).
#   * Schema load: serialized via an atomic "claim" table so only ONE node
#     loads; others wait for the "done" marker. Per-schema guards make it a
#     no-op if the schema is already present (e.g. loaded in a prior session).
#
# Env in (optional): DB_SECRET_ID (default wso2is/db)
set -euo pipefail

IS_HOME=/opt/wso2is
DB_SECRET_ID="${DB_SECRET_ID:-wso2is/db}"
IMDS_TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

J=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ID" --query SecretString --output text --region "$REGION")
HOST=$(echo "$J" | jq -r .host); PORT=$(echo "$J" | jq -r .port)
MUSER=$(echo "$J" | jq -r .master_username); MPASS=$(echo "$J" | jq -r .master_password)
AUSER=$(echo "$J" | jq -r .app_username); APASS=$(echo "$J" | jq -r .app_password)
IDB=$(echo "$J" | jq -r .identity_db); SDB=$(echo "$J" | jq -r .shared_db)

m() { command mysql -h "$HOST" -P "$PORT" -u "$MUSER" -p"$MPASS" --connect-timeout=10 "$@"; }
table_exists() { # table_exists <schema> <table>
  [ "$(m -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$1' AND table_name='$2';")" != "0" ]
}

echo "==> Ensuring databases + app user"
# ALTER USER re-syncs the password to the current secret. This matters after a
# snapshot restore: the snapshot holds the OLD app-user password, but the secret
# was regenerated, so we force them back into agreement on every boot.
m <<SQL
CREATE DATABASE IF NOT EXISTS ${IDB} CHARACTER SET latin1;
CREATE DATABASE IF NOT EXISTS ${SDB} CHARACTER SET latin1;
CREATE USER IF NOT EXISTS '${AUSER}'@'%' IDENTIFIED BY '${APASS}';
ALTER USER '${AUSER}'@'%' IDENTIFIED BY '${APASS}';
GRANT ALL PRIVILEGES ON ${IDB}.* TO '${AUSER}'@'%';
GRANT ALL PRIVILEGES ON ${SDB}.* TO '${AUSER}'@'%';
FLUSH PRIVILEGES;
SQL

load() { # load <database> <script>
  [ -f "$2" ] || { echo "   skip (missing): $2"; return; }
  echo "   loading into $1: $2"; m "$1" < "$2"
}

# Atomic claim: exactly one node creates _init_claim and becomes the loader.
if m -e "CREATE TABLE ${SDB}._init_claim (id INT PRIMARY KEY);" 2>/dev/null; then
  echo "==> This node is the schema initializer"

  if table_exists "$SDB" "UM_TENANT"; then
    echo "   shared schema already present — skip"
  else
    load "$SDB" "${IS_HOME}/dbscripts/mysql.sql"
  fi

  if table_exists "$IDB" "IDN_OAUTH_CONSUMER_APPS"; then
    echo "   identity schema already present — skip"
  else
    load "$IDB" "${IS_HOME}/dbscripts/identity/mysql.sql"
    load "$IDB" "${IS_HOME}/dbscripts/identity/agent/mysql.sql"
    load "$IDB" "${IS_HOME}/dbscripts/consent/mysql.sql"
  fi

  m -e "CREATE TABLE IF NOT EXISTS ${SDB}._init_done (id INT PRIMARY KEY);"
  echo "INIT_DB_COMPLETE"
else
  echo "==> Another node is initializing — waiting for completion"
  for i in $(seq 1 120); do
    if table_exists "$SDB" "_init_done"; then echo "INIT_DB_READY"; exit 0; fi
    sleep 5
  done
  echo "ERROR: timed out waiting for schema init" >&2
  exit 1
fi
