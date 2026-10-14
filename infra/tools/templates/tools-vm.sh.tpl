#!/usr/bin/env bash
# Tools VM bootstrap. Rendered by Terraform templatefile().
set -euo pipefail
exec >>/var/log/tools-bootstrap.log 2>&1

if ! command -v psql >/dev/null; then
  apt-get update -q
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q postgresql-client jq
fi

# Connection details for the scripts in db/ (no secrets here; passwords are
# read from Secret Manager at run time).
cat >/etc/dms-lab.env <<ENV
PROJECT_ID=${project_id}
RDS_HOST=${rds_host}
RDS_ADMIN_USER=${rds_admin_user}
DMS_USER=${dms_user}
ALLOYDB_HOST=${alloydb_host}
DB_NAME=${database_name}
SECRET_PREFIX=${secret_prefix}
ENV
chmod 644 /etc/dms-lab.env
echo "$(date -Is) tools VM ready"
