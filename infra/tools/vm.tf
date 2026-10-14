# Small VM inside the GCP VPC. It reaches RDS over the VPN and AlloyDB over
# Private Services Access, so it loads the mock data, generates live writes,
# and validates both sides. Access is IAP SSH only.
resource "google_service_account" "tools" {
  account_id   = "${var.name}-tools"
  display_name = "DMS lab tools VM"
}

resource "google_project_iam_member" "tools_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.tools.email}"
}

resource "google_secret_manager_secret_iam_member" "tools" {
  for_each  = local.secrets
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.tools.email}"
}

resource "google_compute_instance" "tools" {
  name         = "${var.name}-tools"
  zone         = var.gcp_zone
  machine_type = var.tools_machine_type
  tags         = ["${var.name}-tools"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  # No access_config: no external IP.
  network_interface {
    subnetwork = local.net_gcp.tools_subnet_id
  }

  service_account {
    email  = google_service_account.tools.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/tools-vm.sh.tpl", {
    project_id     = var.project_id
    rds_host       = local.rds.address
    rds_admin_user = local.rds.admin_user
    dms_user       = local.dms.dms_user
    alloydb_host   = local.alloydb.primary_ip
    database_name  = var.database_name
    secret_prefix  = var.name
  })

  depends_on = [google_secret_manager_secret_iam_member.tools]
}
