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
check() {  # check "<label>" <command...>: command prints one item per line, or nothing
  local label="$1"; shift
  local out
  if ! out="$("$@" 2>&1)"; then
    printf '  %-34s ERROR  %s\n' "$label" "$(head -1 <<<"$out")"; leftovers=1; return
  fi
  out="$(sed '/^[[:space:]]*$/d; /^None$/d' <<<"$out")"
  if [[ -z "$out" ]]; then
    printf '  %-34s none\n' "$label"
  else
    printf '  %-34s LEFT:  %s\n' "$label" "$(paste -sd ' ' <<<"$out")"; leftovers=1
  fi
}

G=(--project "$PROJECT" --format=value\(name\))
echo "== Google Cloud ($PROJECT, $REGION)"
check "DMS migration jobs"           gcloud database-migration migration-jobs list --region "$REGION" "${G[@]}" --filter="name~$NAME"
check "DMS connection profiles"      gcloud database-migration connection-profiles list --region "$REGION" "${G[@]}" --filter="name~$NAME"
check "AlloyDB clusters"             gcloud alloydb clusters list --region "$REGION" "${G[@]}" --filter="name~$NAME"
check "Compute instances"            gcloud compute instances list "${G[@]}" --filter="name~^$NAME"
check "VPN tunnels"                  gcloud compute vpn-tunnels list "${G[@]}" --filter="name~^$NAME"
check "HA VPN gateways"              gcloud compute vpn-gateways list "${G[@]}" --filter="name~^$NAME"
check "External VPN gateways"        gcloud compute external-vpn-gateways list "${G[@]}" --filter="name~^$NAME"
check "Cloud Routers / NAT"          gcloud compute routers list "${G[@]}" --filter="name~^$NAME"
check "Reserved ranges (PSA)"        gcloud compute addresses list --global "${G[@]}" --filter="name~^$NAME"
check "VPC networks"                 gcloud compute networks list "${G[@]}" --filter="name~^$NAME"
check "Secret Manager secrets"       gcloud secrets list "${G[@]}" --filter="name~$NAME-"
check "Service accounts"             gcloud iam service-accounts list --project "$PROJECT" --format='value(email)' --filter="email~^$NAME-"

A=(--region "$AWS_REGION" --output text)
echo; echo "== AWS ($AWS_REGION)"
check "RDS instances"                aws rds describe-db-instances "${A[@]}" --query "DBInstances[?starts_with(DBInstanceIdentifier, '$NAME')].DBInstanceIdentifier"
check "RDS parameter groups"         aws rds describe-db-parameter-groups "${A[@]}" --query "DBParameterGroups[?starts_with(DBParameterGroupName, '$NAME')].DBParameterGroupName"
check "RDS subnet groups"            aws rds describe-db-subnet-groups "${A[@]}" --query "DBSubnetGroups[?starts_with(DBSubnetGroupName, '$NAME')].DBSubnetGroupName"
check "VPN connections"              aws ec2 describe-vpn-connections "${A[@]}" --filters "Name=tag:project,Values=$NAME" "Name=state,Values=pending,available" --query 'VpnConnections[].VpnConnectionId'
check "Customer gateways"            aws ec2 describe-customer-gateways "${A[@]}" --filters "Name=tag:project,Values=$NAME" "Name=state,Values=pending,available" --query 'CustomerGateways[].CustomerGatewayId'
check "Virtual private gateways"     aws ec2 describe-vpn-gateways "${A[@]}" --filters "Name=tag:project,Values=$NAME" "Name=state,Values=pending,available" --query 'VpnGateways[].VpnGatewayId'
check "VPCs"                         aws ec2 describe-vpcs "${A[@]}" --filters "Name=tag:project,Values=$NAME" --query 'Vpcs[].VpcId'

echo
if (( leftovers )); then
  echo "Something is still running. Re-run 'scripts/tf.sh all destroy', or delete the items above by hand."
  exit 1
fi
echo "Clean: nothing from '$NAME' is left in either cloud."
