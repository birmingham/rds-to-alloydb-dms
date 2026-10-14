#!/usr/bin/env bash
# After `scripts/tf.sh all destroy`, confirm nothing from this lab is still
# running (and billing) in either cloud. Exits non-zero if anything is left.
# Uses infra/common.tfvars for the project, name prefix and regions, so it
# works even after the Terraform state is empty.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VARS="$ROOT/infra/common.tfvars"
[[ -f "$VARS" ]] || { echo "missing $VARS" >&2; exit 1; }
tfvar() { sed -n "s/^$1 *= *\"\(.*\)\".*/\1/p" "$VARS"; }

PROJECT="$(tfvar project_id)"
NAME="$(tfvar name)";             NAME="${NAME:-dms-lab}"
REGION="$(tfvar gcp_region)";     REGION="${REGION:-us-west1}"
AWS_REGION="$(tfvar aws_region)"; AWS_REGION="${AWS_REGION:-us-west-2}"

leftovers=0
errors=0
ERR="$(mktemp)"; trap 'rm -f "$ERR"' EXIT
# Names (or full resource paths, or emails) that belong to this lab.
MATCH="(^|/)$NAME([-_.@]|\$)"

# check "<label>" <command...>
# The command lists resources one per line (stdout only; gcloud's "Listed 0
# items." goes to stderr and is ignored). Matching is done here rather than
# with --filter, because not every API accepts the same filter syntax.
check() {
  local label="$1"; shift
  local out
  if ! out="$("$@" 2>"$ERR")"; then
    printf '  %-34s ERROR  %s\n' "$label" "$(grep -m1 . "$ERR")"; errors=1; return
  fi
  out="$(tr '\t' '\n' <<<"$out" | grep -E "$MATCH" | sed 's#.*/##' || true)"
  if [[ -z "$out" ]]; then
    printf '  %-34s none\n' "$label"
  else
    printf '  %-34s LEFT:  %s\n' "$label" "$(tr '\n' ' ' <<<"$out")"; leftovers=1
  fi
}

G=(--project "$PROJECT" --format='value(name)')
echo "== Google Cloud ($PROJECT, $REGION)"
check "DMS migration jobs"           gcloud database-migration migration-jobs list --region "$REGION" "${G[@]}"
check "DMS connection profiles"      gcloud database-migration connection-profiles list --region "$REGION" "${G[@]}"
check "AlloyDB clusters"             gcloud alloydb clusters list --region "$REGION" "${G[@]}"
check "Compute instances"            gcloud compute instances list "${G[@]}"
check "VPN tunnels"                  gcloud compute vpn-tunnels list "${G[@]}"
check "HA VPN gateways"              gcloud compute vpn-gateways list "${G[@]}"
check "External VPN gateways"        gcloud compute external-vpn-gateways list "${G[@]}"
check "Cloud Routers / NAT"          gcloud compute routers list "${G[@]}"
check "Reserved ranges (PSA)"        gcloud compute addresses list --global "${G[@]}"
check "VPC networks"                 gcloud compute networks list "${G[@]}"
check "Secret Manager secrets"       gcloud secrets list "${G[@]}"
check "Service accounts"             gcloud iam service-accounts list --project "$PROJECT" --format='value(email)'

# AWS: filter server-side by the project tag / name prefix; text output.
A=(--region "$AWS_REGION" --output text)
echo; echo "== AWS ($AWS_REGION)"
check "RDS instances"                aws rds describe-db-instances "${A[@]}" --query 'DBInstances[].DBInstanceIdentifier'
check "RDS parameter groups"         aws rds describe-db-parameter-groups "${A[@]}" --query 'DBParameterGroups[].DBParameterGroupName'
check "RDS subnet groups"            aws rds describe-db-subnet-groups "${A[@]}" --query 'DBSubnetGroups[].DBSubnetGroupName'
check "VPN connections"              aws ec2 describe-vpn-connections "${A[@]}" --filters "Name=state,Values=pending,available" --query "VpnConnections[?Tags[?Key=='project' && Value=='$NAME']].Tags[?Key=='Name'].Value[]"
check "Customer gateways"            aws ec2 describe-customer-gateways "${A[@]}" --filters "Name=state,Values=pending,available" --query "CustomerGateways[?Tags[?Key=='project' && Value=='$NAME']].Tags[?Key=='Name'].Value[]"
check "Virtual private gateways"     aws ec2 describe-vpn-gateways "${A[@]}" --filters "Name=state,Values=pending,available" --query "VpnGateways[?Tags[?Key=='project' && Value=='$NAME']].Tags[?Key=='Name'].Value[]"
check "VPCs"                         aws ec2 describe-vpcs "${A[@]}" --filters "Name=tag:project,Values=$NAME" --query "Vpcs[].Tags[?Key=='Name'].Value[]"

echo
if (( leftovers )); then
  echo "Something is still running. Re-run 'scripts/tf.sh all destroy', or delete the items above by hand."
fi
if (( errors )); then
  echo "Some checks couldn't run (see ERROR lines); those resource types weren't verified."
fi
(( leftovers || errors )) && exit 1
echo "Clean: nothing from '$NAME' is left in either cloud."
