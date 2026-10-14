# GCP half of the HA VPN: an HA gateway (2 interfaces), the four AWS tunnel
# endpoints as an external gateway, four tunnels, and a BGP session per tunnel.

resource "google_compute_ha_vpn_gateway" "gw" {
  name    = "${var.name}-ha-vpn"
  region  = var.gcp_region
  network = local.net_gcp.network_id
}

locals {
  # Tunnel i: AWS connection i/2, AWS tunnel (i%2)+1, GCP interface i/2.
  aws_tunnels = [
    for i in range(4) : {
      address    = i % 2 == 0 ? aws_vpn_connection.gcp[floor(i / 2)].tunnel1_address : aws_vpn_connection.gcp[floor(i / 2)].tunnel2_address
      cgw_inside = i % 2 == 0 ? aws_vpn_connection.gcp[floor(i / 2)].tunnel1_cgw_inside_address : aws_vpn_connection.gcp[floor(i / 2)].tunnel2_cgw_inside_address
      vgw_inside = i % 2 == 0 ? aws_vpn_connection.gcp[floor(i / 2)].tunnel1_vgw_inside_address : aws_vpn_connection.gcp[floor(i / 2)].tunnel2_vgw_inside_address
      gcp_if     = floor(i / 2)
      psk        = local.psk[i]
    }
  ]
}

resource "google_compute_external_vpn_gateway" "aws" {
  name            = "${var.name}-aws"
  redundancy_type = "FOUR_IPS_REDUNDANCY"

  dynamic "interface" {
    for_each = local.aws_tunnels
    content {
      id         = interface.key
      ip_address = interface.value.address
    }
  }
}

resource "google_compute_vpn_tunnel" "aws" {
  count                           = 4
  name                            = "${var.name}-aws-${count.index}"
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.gw.id
  vpn_gateway_interface           = local.aws_tunnels[count.index].gcp_if
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = count.index
  shared_secret                   = local.aws_tunnels[count.index].psk
  router                          = local.net_gcp.router_id
  ike_version                     = 2
}

resource "google_compute_router_interface" "aws" {
  count      = 4
  name       = "${var.name}-aws-if-${count.index}"
  router     = local.net_gcp.router_name
  region     = var.gcp_region
  ip_range   = "${local.aws_tunnels[count.index].cgw_inside}/30"
  vpn_tunnel = google_compute_vpn_tunnel.aws[count.index].name
}

resource "google_compute_router_peer" "aws" {
  count           = 4
  name            = "${var.name}-aws-peer-${count.index}"
  router          = local.net_gcp.router_name
  region          = var.gcp_region
  interface       = google_compute_router_interface.aws[count.index].name
  peer_ip_address = local.aws_tunnels[count.index].vgw_inside
  peer_asn        = local.net_aws.vgw_asn
}
