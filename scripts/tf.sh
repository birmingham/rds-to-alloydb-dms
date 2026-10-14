#!/usr/bin/env bash
# Run Terraform for one stack, or for all of them in dependency order.
#
#   scripts/tf.sh <stack> <command> [terraform args...]
#   scripts/tf.sh <stack> check          fmt -check + init + validate
#   scripts/tf.sh all     <check|fmt|init|validate|plan|apply|destroy>
#
# Reviewed workflow (what you apply is exactly what you reviewed):
#   scripts/tf.sh <stack> plan -out=tfplan
#   scripts/tf.sh <stack> apply tfplan     # the plan file is deleted afterwards
#
# Stacks: network/gcp network/aws vpn database/aws_rds database/alloydb dms tools
# Each stack has its own state at gs://<state_bucket>/<state_prefix>/<stack>.
# infra/common.tfvars supplies the shared variables to every stack.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INFRA="$ROOT/infra"
VARS="$INFRA/common.tfvars"
ORDER=(network/gcp network/aws vpn database/aws_rds database/alloydb dms tools)

die() { echo "$*" >&2; exit 1; }
[[ $# -ge 2 ]] || die "usage: $0 <stack|all> <command> [args...]"
[[ -f "$VARS" ]] || die "missing $VARS: cp infra/common.tfvars.example infra/common.tfvars and edit it"

bucket="$(sed -n 's/^state_bucket *= *"\(.*\)".*/\1/p' "$VARS")"
prefix="$(sed -n 's/^state_prefix *= *"\(.*\)".*/\1/p' "$VARS")"
prefix="${prefix:-rds-to-alloydb-dms}"
[[ -n "$bucket" ]] || die "state_bucket is not set in $VARS"

init_stack() {
  local stack="$1"; shift
  terraform -chdir="$INFRA/$stack" init -input=false \
    -backend-config="bucket=$bucket" -backend-config="prefix=$prefix/$stack" "$@"
}

run_stack() {
  local stack="$1" cmd="$2"; shift 2
  [[ -d "$INFRA/$stack" ]] || die "unknown stack: $stack (one of: ${ORDER[*]})"
  echo; echo "=== $stack: terraform $cmd"
  if [[ "$cmd" == "init" ]]; then
    init_stack "$stack" "$@"; return
  fi
  if [[ "$cmd" == "check" ]]; then
    terraform -chdir="$INFRA/$stack" fmt -check -diff \
      || die "$stack: formatting differs; fix with: scripts/tf.sh $stack fmt"
    echo "fmt: ok"
    init_stack "$stack" >/dev/null
    echo "init: ok (state: gs://$bucket/$prefix/$stack)"
    terraform -chdir="$INFRA/$stack" validate
    return
  fi
  [[ -d "$INFRA/$stack/.terraform" ]] || init_stack "$stack" >/dev/null

  # A saved plan already contains its variables; Terraform rejects -var-file with one.
  local plan_file=""
  if [[ "$cmd" == "apply" ]]; then
    for a in "$@"; do [[ "$a" != -* ]] && plan_file="$a"; done
  fi

  case "$cmd" in
    apply)
      if [[ -n "$plan_file" ]]; then
        terraform -chdir="$INFRA/$stack" apply "$@"
        # Plan files hold every sensitive value in plain text; don't leave them around.
        rm -f "$INFRA/$stack/$plan_file"
      else
        terraform -chdir="$INFRA/$stack" apply -var-file="$VARS" "$@"
      fi ;;
    plan|destroy|import|refresh|console)
      terraform -chdir="$INFRA/$stack" "$cmd" -var-file="$VARS" "$@" ;;
    *)
      terraform -chdir="$INFRA/$stack" "$cmd" "$@" ;;
  esac
  # Outputs may have changed; make the other scripts re-read them.
  [[ "$cmd" == "apply" || "$cmd" == "destroy" ]] && rm -f "$ROOT/.lab-env"
  return 0
}

stack="$1"; shift
if [[ "$stack" != "all" ]]; then
  run_stack "$stack" "$@"
  exit
fi

cmd="$1"; shift
case "$cmd" in
  check|fmt|init|validate|plan|apply)
    for s in "${ORDER[@]}"; do run_stack "$s" "$cmd" "$@"; done ;;
  destroy)
    for (( i=${#ORDER[@]}-1; i>=0; i-- )); do run_stack "${ORDER[$i]}" destroy "$@"; done ;;
  *)
    die "'all' supports check, fmt, init, validate, plan, apply, destroy" ;;
esac
