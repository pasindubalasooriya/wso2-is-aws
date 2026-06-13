# WSO2 IS 7.3 deployment.toml — rendered by bootstrap.sh.
# Restricted envsubst replaces only ${UPPER_CASE} vars; WSO2 $ref{...} survives.

[server]
hostname = "${HOSTNAME}"
node_ip = "${NODE_IP}"
base_path = "https://$ref{server.hostname}:${PROXY_PORT}"
force_local_cache = true

[super_admin]
username = "admin"
password = "${ADMIN_PASSWORD}"
create_admin_account = true

[user_store]
type = "database_unique_id"

# ----- Identity DB -----
[database.identity_db]
type = "mysql"
url = "jdbc:mysql://${DB_HOST}:${DB_PORT}/${IDENTITY_DB}?useSSL=false&amp;allowPublicKeyRetrieval=true"
username = "${APP_USER}"
password = "${APP_PASSWORD}"
driver = "com.mysql.cj.jdbc.Driver"

[database.identity_db.pool_options]
maxActive = "50"
maxWait = "60000"
validationQuery = "SELECT 1"
testOnBorrow = true

# ----- Shared DB (registry / user mgmt) -----
[database.shared_db]
type = "mysql"
url = "jdbc:mysql://${DB_HOST}:${DB_PORT}/${SHARED_DB}?useSSL=false&amp;allowPublicKeyRetrieval=true"
username = "${APP_USER}"
password = "${APP_PASSWORD}"
driver = "com.mysql.cj.jdbc.Driver"

[database.shared_db.pool_options]
maxActive = "50"
maxWait = "60000"
validationQuery = "SELECT 1"
testOnBorrow = true

# ----- Clustering (WKA; members discovered from EC2 at boot, written here) -----
# IS 7.3 doesn't bundle the hazelcast-aws discovery library, so we emulate it:
# bootstrap.sh queries EC2 by the Cluster tag and fills ${MEMBERS}.
[clustering]
membership_scheme = "wka"
local_member_host = "${NODE_IP}"
local_member_port = "4000"
members = ${MEMBERS}

# ----- Behind ALB: advertise the proxy port (443 in Phase 4) -----
[transport.https.properties]
proxyPort = ${PROXY_PORT}
