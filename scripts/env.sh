#!/usr/bin/env bash
# Shared settings for local scripts, read from each stack's Terraform outputs.
# Cached in .lab-env (gitignored); scripts/tf.sh clears it after apply/destroy,
# or run with REFRESH=1 to force a re-read.
# shellcheck disable=SC2034  # variables are used by the scripts that source this
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="$ROOT/.lab-env"

PROJECT="${PROJECT:-$(gcloud config get-value project 2>/dev/null)}"
[[ -n "$PROJECT" ]] || { echo "project ID is empty: export PROJECT=..." >&2; exit 1; }

tfout() { terraform -chdir="$ROOT/infra/$1" output -raw "$2"; }

if [[ "${REFRESH:-0}" == "1" || ! -f "$CACHE" ]]; then
  {
    echo "REGION=$(tfout network/gcp region)"
    echo "ROUTER=$(tfout network/gcp router_name)"
    echo "PSA_CIDR=$(tfout network/gcp psa_cidr)"
    echo "AWS_REGION=$(tfout network/aws region)"
    echo "VPN_IDS=\"$(terraform -chdir="$ROOT/infra/vpn" output -json aws_vpn_connection_ids | jq -r 'join(" ")')\""
    echo "RDS_ID=$(tfout database/aws_rds identifier)"
    echo "JOB=$(tfout dms migration_job)"
    echo "VM=$(tfout tools tools_vm)"
    echo "ZONE=$(tfout tools zone)"
  } >"$CACHE.tmp"
  mv "$CACHE.tmp" "$CACHE"
fi
# shellcheck disable=SC1090
source "$CACHE"
