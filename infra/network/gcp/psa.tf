# AlloyDB instances live in a Google-managed VPC, connected to ours by
# Private Services Access (VPC peering). DMS runs the replication *from the
# AlloyDB side*, so connections to RDS originate from this range.
resource "google_compute_global_address" "psa" {
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.psa_address
  prefix_length = var.psa_prefix
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]

  # Removing the peering often fails while AlloyDB is still tearing down;
  # it is deleted with the network instead.
  deletion_policy = "ABANDON"
}

# Gotcha #1: by default the peering does not share dynamic (BGP-learned)
# routes, so the AlloyDB side has no route to the AWS VPC. Export our custom
# routes into the peering (and import theirs) so AlloyDB can reach RDS over
# the VPN.
resource "google_compute_network_peering_routes_config" "psa" {
  peering              = google_service_networking_connection.psa.peering
  network              = google_compute_network.vpc.name
  import_custom_routes = true
  export_custom_routes = true
}
