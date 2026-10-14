# AWS half of the HA VPN: one customer gateway per GCP HA VPN interface, and
# one VPN connection (two tunnels each) per customer gateway = 4 tunnels.

resource "random_password" "psk" {
  count   = 4
  length  = 40
  special = false
}

locals {
  # AWS rejects pre-shared keys that start with "0"; prefix to be safe.
  psk = [for p in random_password.psk : "k${p.result}"]
}

resource "aws_customer_gateway" "gcp" {
  count      = 2
  bgp_asn    = local.net_gcp.router_asn
  ip_address = google_compute_ha_vpn_gateway.gw.vpn_interfaces[count.index].ip_address
  type       = "ipsec.1"
  tags       = { Name = "${var.name}-gcp-if${count.index}" }
}

resource "aws_vpn_connection" "gcp" {
  count               = 2
  vpn_gateway_id      = local.net_aws.vgw_id
  customer_gateway_id = aws_customer_gateway.gcp[count.index].id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr   = var.tunnel_inside_cidrs[count.index * 2]
  tunnel2_inside_cidr   = var.tunnel_inside_cidrs[count.index * 2 + 1]
  tunnel1_preshared_key = local.psk[count.index * 2]
  tunnel2_preshared_key = local.psk[count.index * 2 + 1]
  tunnel1_ike_versions  = ["ikev2"]
  tunnel2_ike_versions  = ["ikev2"]

  tags = { Name = "${var.name}-to-gcp-${count.index}" }
}
