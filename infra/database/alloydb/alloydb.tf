# Created by Terraform, then demoted to a replica by DMS before the job
# starts. DMS requires the destination to be empty: don't create tables here.
resource "google_alloydb_cluster" "dest" {
  cluster_id       = "${var.name}-alloydb"
  location         = var.gcp_region
  database_version = var.alloydb_database_version

  network_config {
    network            = local.net_gcp.network_id
    allocated_ip_range = local.net_gcp.psa_range_name
  }

  initial_user {
    user     = "postgres"
    password = random_password.postgres.result
  }

  deletion_policy     = "FORCE"
  deletion_protection = false

}

resource "google_alloydb_instance" "primary" {
  cluster           = google_alloydb_cluster.dest.name
  instance_id       = "${var.name}-primary"
  instance_type     = "PRIMARY"
  availability_type = var.alloydb_availability_type

  machine_config {
    cpu_count = var.alloydb_cpu_count
  }
}
