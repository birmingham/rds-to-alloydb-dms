#!/usr/bin/env bash
# Run Terraform for one stack, or for all of them in dependency order.
#
#   scripts/tf.sh <stack> <command> [terraform args...]
#   scripts/tf.sh <stack> check          fmt -check + init + validate
#   scripts/tf.sh <stack> lock           record provider checksums for every platform
#   scripts/tf.sh all     <check|lock|fmt|init|validate|plan|apply|destroy>
#   scripts/tf.sh all destroy -auto-approve      unattended teardown, no prompts
#
# Reviewed workflow (what you apply is exactly what you reviewed):
#   scripts/tf.sh infra/network/gcp plan -out=tfplan
#   scripts/tf.sh infra/network/gcp apply tfplan   # the plan file is deleted afterwards
#
# <stack> is the stack's folder: infra/network/gcp, or just network/gcp
# (a trailing slash from tab completion is fine).
# Stacks: network/gcp network/aws vpn database/aws_rds database/alloydb dms tools
# Each stack has its own state at gs://<state_bucket>/<state_prefix>/<stack>.
# infra/common.tfvars supplies the shared variables to every stack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFRA="$ROOT/infra"
VARS="$INFRA/common.tfvars"
ORDER=(network/gcp network/aws vpn database/aws_rds database/alloydb dms tools)
# Platforms recorded in .terraform.lock.hcl: Apple Silicon and Intel Macs, and
# the Linux runners CI uses.
LOCK_PLATFORMS=(darwin_arm64 darwin_amd64 linux_amd64)

die() { echo "$*" >&2; exit 1; }
[[ $# -ge 2 ]] || die "usage: $0 <stack|all> <command> [args...]"
[[ -f "$VARS" ]] || die "missing $VARS: cp infra/common.tfvars.example infra/common.tfvars and edit it"

tfvar() { sed -n "s/^$1 *= *\"\(.*\)\".*/\1/p" "$VARS"; }
bucket="$(tfvar state_bucket)"
prefix="$(tfvar state_prefix)"
prefix="${prefix:-rds-to-alloydb-dms}"
[[ -n "$bucket" ]] || die "state_bucket is not set in $VARS"

init_stack() {
  local stack="$1"; shift
  terraform -chdir="$INFRA/$stack" init -input=false \
    -backend-config="bucket=$bucket" -backend-config="prefix=$prefix/$stack" "$@"
}

# network/gcp destroy can fail at the very end: Google may take several
# minutes after AlloyDB is deleted to release the private services access
# peering, and until then the PSA range and the VPC count as "in use".
# Wait, remove the peering, and retry, so unattended teardowns still finish.
destroy_network_gcp() {
  local project name attempt
  project="$(tfvar project_id)"
  name="$(tfvar name)"; name="${name:-dms-lab}"
  for attempt in 1 2 3; do
    if terraform -chdir="$INFRA/network/gcp" destroy -var-file="$VARS" "$@"; then
      return 0
    fi
    (( attempt == 3 )) && break
    echo "network/gcp: destroy failed (attempt $attempt/3). Usually Google hasn't released the" >&2
    echo "AlloyDB peering yet. Waiting 2 minutes, removing the peering, and retrying..." >&2
    sleep "${PEERING_RETRY_WAIT:-120}"
    gcloud services vpc-peerings delete --network="$name-vpc" \
      --service=servicenetworking.googleapis.com --project "$project" --quiet || true
  done
  die "network/gcp: destroy still failing after 3 attempts; see the error above"
}

run_stack() {
  local stack="$1" cmd="$2"; shift 2
  [[ -d "$INFRA/$stack" ]] || die "unknown stack: $stack (one of: ${ORDER[*]/#/infra/})"
  echo; echo "=== $stack: terraform $cmd"
  if [[ "$cmd" == "init" ]]; then
    init_stack "$stack" "$@"; return
  fi
  if [[ "$cmd" == "check" ]]; then
    terraform -chdir="$INFRA/$stack" fmt -check -diff \
      || die "$stack: formatting differs; fix with: scripts/tf.sh infra/$stack fmt"
    echo "fmt: ok"
    init_stack "$stack" >/dev/null
    echo "init: ok (state: gs://$bucket/$prefix/$stack)"
    terraform -chdir="$INFRA/$stack" validate
    return
  fi
  [[ -d "$INFRA/$stack/.terraform" ]] || init_stack "$stack" >/dev/null

  if [[ "$cmd" == "lock" ]]; then
    terraform -chdir="$INFRA/$stack" providers lock "${LOCK_PLATFORMS[@]/#/-platform=}" "$@"
    return
  fi

  # A saved plan already contains its variables; Terraform rejects -var-file with one.
  local plan_file=""
  if [[ "$cmd" == "apply" ]]; then
    for a in "$@"; do [[ "$a" != -* ]] && plan_file="$a"; done
  fi

  case "$cmd" in
    apply)
      if [[ -n "$plan_file" ]]; then
        # Plan files hold every sensitive value in plain text, and after an
        # apply (successful or not) the plan is spent: delete it either way.
        local status=0
        terraform -chdir="$INFRA/$stack" apply "$@" || status=$?
        rm -f "$INFRA/$stack/$plan_file"
        if (( status != 0 )); then
          echo "$stack: apply failed; fix the error, then plan again (the plan file was removed)" >&2
          exit "$status"
        fi
      else
        terraform -chdir="$INFRA/$stack" apply -var-file="$VARS" "$@"
      fi ;;
    destroy)
      if [[ "$stack" == "network/gcp" ]]; then
        destroy_network_gcp "$@"
      else
        terraform -chdir="$INFRA/$stack" destroy -var-file="$VARS" "$@"
      fi ;;
    plan|import|refresh|console)
      terraform -chdir="$INFRA/$stack" "$cmd" -var-file="$VARS" "$@" ;;
    *)
      terraform -chdir="$INFRA/$stack" "$cmd" "$@" ;;
  esac
  # Outputs may have changed; make the other scripts re-read them.
  [[ "$cmd" == "apply" || "$cmd" == "destroy" ]] && rm -f "$ROOT/.lab-env"
  return 0
}

# Accept "infra/network/gcp", "./infra/network/gcp/" or "network/gcp".
stack="$1"; shift
stack="${stack#./}"; stack="${stack#infra/}"; stack="${stack%/}"
if [[ "$stack" != "all" ]]; then
  run_stack "$stack" "$@"
  exit
fi

cmd="$1"; shift
case "$cmd" in
  check|lock|fmt|init|validate|plan|apply)
    for s in "${ORDER[@]}"; do run_stack "$s" "$cmd" "$@"; done ;;
  destroy)
    for (( i=${#ORDER[@]}-1; i>=0; i-- )); do run_stack "${ORDER[$i]}" destroy "$@"; done ;;
  *)
    die "'all' supports check, lock, fmt, init, validate, plan, apply, destroy" ;;
esac
