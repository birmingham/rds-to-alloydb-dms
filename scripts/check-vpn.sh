#!/usr/bin/env bash
# Show the HA VPN from both sides: tunnel status, BGP sessions, and the routes
# that matter (AWS VPC learned by GCP; GCP subnet + AlloyDB range learned by AWS).
set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "== GCP tunnels"
gcloud compute vpn-tunnels list --project "$PROJECT" --filter="region:$REGION" \
  --format="table(name, status, detailedStatus)"

echo; echo "== GCP Cloud Router BGP sessions"
status_json="$(gcloud compute routers get-status "$ROUTER" --region "$REGION" --project "$PROJECT" --format=json)"
jq -r '["PEER","STATUS","LEARNED_ROUTES"], (.result.bgpPeerStatus[] | [.name, .status, (.numLearnedRoutes // 0 | tostring)]) | @tsv' \
  <<<"$status_json" | column -t

echo; echo "== Routes GCP learned from AWS"
jq -r '.result.bestRoutes[]? | select(.routeType == "BGP") | "  \(.destRange) via \(.nextHopIp)"' <<<"$status_json" | sort -u

echo; echo "== AWS tunnels"
# shellcheck disable=SC2086  # VPN_IDS is a space-separated list
aws ec2 describe-vpn-connections --region "$AWS_REGION" --vpn-connection-ids $VPN_IDS \
  --query 'VpnConnections[].VgwTelemetry[].[OutsideIpAddress, Status, StatusMessage]' --output table

echo; echo "== Routes AWS learned from GCP (expect the tools subnet and $PSA_CIDR)"
# shellcheck disable=SC2016  # backticks are JMESPath literals, not shell
aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=*-private" \
  --query 'RouteTables[].Routes[?Origin==`EnableVgwRoutePropagation`].[DestinationCidrBlock, State]' --output table
