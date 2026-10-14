# Admin password, stored in Secret Manager for the tools VM. Also in this
# stack's Terraform state: keep the state bucket private.
resource "random_password" "admin" {
  length  = 28
  special = false
}

resource "google_secret_manager_secret" "admin" {
  secret_id = "${var.name}-rds-admin-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "admin" {
  secret      = google_secret_manager_secret.admin.id
  secret_data = random_password.admin.result
}
