# Password for the dedicated replication user. db/bootstrap-source.sh creates
# the user on RDS with this password, read from Secret Manager.
resource "random_password" "dms_user" {
  length  = 28
  special = false
}

resource "google_secret_manager_secret" "dms_user" {
  secret_id = "${var.name}-dms-user-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "dms_user" {
  secret      = google_secret_manager_secret.dms_user.id
  secret_data = random_password.dms_user.result
}
