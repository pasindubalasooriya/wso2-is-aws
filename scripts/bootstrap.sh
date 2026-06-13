#!/usr/bin/env bash
# WSO2 IS node bootstrap — installs JDK21 + IS 7.3 + MySQL connector, renders
# deployment.toml from Secrets Manager, installs the systemd unit.
# Does NOT init the DB or start IS (Phase 3 drives those over SSM).
#
# Env in: ARTIFACTS_BUCKET DB_SECRET_ID ADMIN_SECRET_ID CLUSTER_TAG PROXY_PORT REGION
set -euxo pipefail

IS_HOME=/opt/wso2is
IS_ZIP=wso2is-7.3.0.zip
CORRETTO_RPM=amazon-corretto-21-x64-linux-jdk.rpm
MYSQL_CONNECTOR_VER=8.4.0

export PATH=$PATH:/usr/local/bin
: "${REGION:=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)}"

# --- Packages ---
dnf install -y unzip jq mariadb105 gettext

# --- JDK 21 (Corretto, from S3 cache) ---
aws s3 cp "s3://${ARTIFACTS_BUCKET}/${CORRETTO_RPM}" /tmp/${CORRETTO_RPM} --region "$REGION"
dnf install -y /tmp/${CORRETTO_RPM}

# --- WSO2 IS (from S3 cache) ---
if [ ! -d "$IS_HOME" ]; then
  aws s3 cp "s3://${ARTIFACTS_BUCKET}/${IS_ZIP}" /tmp/${IS_ZIP} --region "$REGION"
  unzip -q /tmp/${IS_ZIP} -d /opt
  mv /opt/wso2is-7.3.0 "$IS_HOME"
fi

# --- service account ---
id wso2 &>/dev/null || useradd -r -s /sbin/nologin wso2

# --- MySQL Connector/J ---
curl -fL --retry 3 -o "${IS_HOME}/repository/components/lib/mysql-connector-j-${MYSQL_CONNECTOR_VER}.jar" \
  "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VER}/mysql-connector-j-${MYSQL_CONNECTOR_VER}.jar"

# --- secrets ---
DB_JSON=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ID" --query SecretString --output text --region "$REGION")
ADMIN_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$ADMIN_SECRET_ID" --query SecretString --output text --region "$REGION" | jq -r .password)

export DB_HOST=$(echo "$DB_JSON" | jq -r .host)
export DB_PORT=$(echo "$DB_JSON" | jq -r .port)
export IDENTITY_DB=$(echo "$DB_JSON" | jq -r .identity_db)
export SHARED_DB=$(echo "$DB_JSON" | jq -r .shared_db)
export APP_USER=$(echo "$DB_JSON" | jq -r .app_username)
export APP_PASSWORD=$(echo "$DB_JSON" | jq -r .app_password)
export ADMIN_PASSWORD

# --- node identity ---
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
export NODE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
# Behind the ALB, advertise the ALB DNS so redirects/issuer URLs are correct;
# fall back to the node IP for a standalone node (Phase 3).
export HOSTNAME="${SERVER_HOSTNAME:-$NODE_IP}"
export PROXY_PORT
export REGION
export CLUSTER_TAG

# --- WKA membership discovery: find peer IPs via EC2 (emulates hazelcast-aws) ---
# Retry briefly so co-booting nodes find each other; proceed with whatever we
# have on timeout (a node always includes at least itself).
EXPECTED_NODE_COUNT="${EXPECTED_NODE_COUNT:-1}"
build_members() {
  local ips arr=""
  ips=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Cluster,Values=${CLUSTER_TAG}" "Name=instance-state-name,Values=running,pending" \
    --query 'Reservations[].Instances[].PrivateIpAddress' --output text 2>/dev/null | tr '\t' '\n' | sort -u)
  for ip in $ips; do [ -n "$ip" ] && arr="${arr}\"${ip}:4000\","; done
  echo "[${arr%,}]"
}
for i in $(seq 1 18); do
  MEMBERS=$(build_members)
  COUNT=$(echo "$MEMBERS" | grep -o ':4000' | wc -l)
  echo "discovery attempt $i: members=$MEMBERS (count=$COUNT, expected=$EXPECTED_NODE_COUNT)"
  [ "$COUNT" -ge "$EXPECTED_NODE_COUNT" ] && break
  sleep 5
done
# Fallback to self if discovery returned nothing.
[ "$MEMBERS" = "[]" ] && MEMBERS="[\"${NODE_IP}:4000\"]"
export MEMBERS

# --- render deployment.toml (restricted envsubst keeps WSO2 $ref{} intact) ---
aws s3 cp "s3://${ARTIFACTS_BUCKET}/config/deployment.toml.tpl" /tmp/deployment.toml.tpl --region "$REGION"
envsubst '${HOSTNAME} ${NODE_IP} ${PROXY_PORT} ${ADMIN_PASSWORD} ${DB_HOST} ${DB_PORT} ${IDENTITY_DB} ${SHARED_DB} ${APP_USER} ${APP_PASSWORD} ${REGION} ${CLUSTER_TAG} ${MEMBERS}' \
  < /tmp/deployment.toml.tpl > "${IS_HOME}/repository/conf/deployment.toml"

chown -R wso2:wso2 "$IS_HOME"

# --- systemd unit ---
aws s3 cp "s3://${ARTIFACTS_BUCKET}/config/wso2is.service" /etc/systemd/system/wso2is.service --region "$REGION"
systemctl daemon-reload
systemctl enable wso2is

# --- CloudWatch agent: ship logs + node metrics ---
dnf install -y amazon-cloudwatch-agent
aws s3 cp "s3://${ARTIFACTS_BUCKET}/config/cw-agent-config.json" /opt/aws/amazon-cloudwatch-agent/etc/cw-agent-config.json --region "$REGION"
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/cw-agent-config.json

# --- one-time-safe DB init (idempotent + concurrency-safe across nodes) ---
aws s3 cp "s3://${ARTIFACTS_BUCKET}/scripts/init-db.sh" /opt/init-db.sh --region "$REGION"
chmod +x /opt/init-db.sh
DB_SECRET_ID="$DB_SECRET_ID" bash /opt/init-db.sh

# --- start IS (nodes self-start so the ASG/ELB health checks pass) ---
systemctl start wso2is

echo "BOOTSTRAP_COMPLETE"
