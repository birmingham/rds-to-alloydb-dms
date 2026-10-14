# Consumed by the vpn, database, dms and tools stacks via terraform_remote_state.

output "region" {
  value = var.gcp_region
}

output "zone" {
  value = var.gcp_zone
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "network_name" {
  value = google_compute_network.vpc.name
}

output "tools_subnet_id" {
  value = google_compute_subnetwork.tools.id
}

output "tools_subnet_cidr" {
  value = google_compute_subnetwork.tools.ip_cidr_range
}

output "router_name" {
  value = google_compute_router.router.name
}

output "router_id" {
  value = google_compute_router.router.id
}

output "router_asn" {
  value = var.gcp_router_asn
}

output "psa_range_name" {
  value = google_compute_global_address.psa.name
}

output "psa_cidr" {
  value = local.psa_cidr
}
