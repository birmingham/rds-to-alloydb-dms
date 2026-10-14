resource "random_password" "postgres" {
  length  = 28
  special = false
}

resource "google_secret_manager_secret" "postgres" {
  secret_id = "${var.name}-alloydb-postgres-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "postgres" {
  secret      = google_secret_manager_secret.postgres.id
  secret_data = random_password.postgres.result
}
