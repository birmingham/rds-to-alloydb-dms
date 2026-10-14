#!/usr/bin/env bash
# Shared helpers for scripts that run on the tools VM.
set -euo pipefail

# shellcheck disable=SC1091
source /etc/dms-lab.env

export PGSSLMODE=require      # RDS 15+ forces SSL; AlloyDB requires it too
export PGCONNECT_TIMEOUT=10
export PGTZ=UTC               # identical timestamp text on both sides for checksums

secret() {
  gcloud secrets versions access latest --secret="${SECRET_PREFIX}-$1-password" --project "$PROJECT_ID"
}

_RDS_PW=""
_ALLOYDB_PW=""

# src DB [psql args...]: RDS source as the admin user
src() {
  local db="$1"; shift
  [[ -n "$_RDS_PW" ]] || _RDS_PW="$(secret rds-admin)"
  PGPASSWORD="$_RDS_PW" psql -h "$RDS_HOST" -U "$RDS_ADMIN_USER" -d "$db" -X -q -v ON_ERROR_STOP=1 "$@"
}

# dst DB [psql args...]: AlloyDB destination as postgres
dst() {
  local db="$1"; shift
  [[ -n "$_ALLOYDB_PW" ]] || _ALLOYDB_PW="$(secret alloydb-postgres)"
  PGPASSWORD="$_ALLOYDB_PW" psql -h "$ALLOYDB_HOST" -U postgres -d "$db" -X -q -v ON_ERROR_STOP=1 "$@"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
