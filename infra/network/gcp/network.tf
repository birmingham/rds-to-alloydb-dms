resource "google_compute_network" "vpc" {
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "tools" {
  name                     = "${var.name}-tools"
  region                   = var.gcp_region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.gcp_subnet_cidr
  private_ip_google_access = true
}

# IAP's TCP forwarding range: SSH to the tools VM, nothing from the internet.
resource "google_compute_firewall" "iap_ssh" {
  name          = "${var.name}-allow-iap-ssh"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.name}-tools"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# One Cloud Router does both jobs: BGP for the HA VPN and Cloud NAT for the
# tools VM's package installs.
resource "google_compute_router" "router" {
  name    = "${var.name}-router"
  region  = var.gcp_region
  network = google_compute_network.vpc.id

  bgp {
    asn               = var.gcp_router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    # Gotcha #2: ALL_SUBNETS covers this VPC's own subnets, but not the
    # AlloyDB range, which lives in Google's peered service-producer VPC.
    # Without this, AWS has no route back to AlloyDB and the DMS
    # connection from AlloyDB to RDS times out.
    advertised_ip_ranges {
      range       = local.psa_cidr
      description = "AlloyDB private services access range"
    }
  }
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.gcp_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
