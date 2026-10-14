#!/usr/bin/env bash
# Copy db/ to the tools VM and run one of its scripts there over IAP.
# Usage: scripts/vm.sh <script.sh> [args...]
#   scripts/vm.sh bootstrap-source.sh      scripts/vm.sh load.sh start
#   scripts/vm.sh lag.sh --watch           scripts/vm.sh validate.sh
set -euo pipefail
source "$(dirname "$0")/env.sh"
[[ $# -ge 1 ]] || { echo "usage: $0 <script.sh> [args...]" >&2; exit 64; }

gcloud compute scp --recurse --quiet --tunnel-through-iap --zone "$ZONE" --project "$PROJECT" \
  "$ROOT/db" "$VM":~ >/dev/null

cmd="cd ~/db && bash $(printf '%q ' "$@")"
exec gcloud compute ssh "$VM" --tunnel-through-iap --zone "$ZONE" --project "$PROJECT" -- -t "$cmd"
