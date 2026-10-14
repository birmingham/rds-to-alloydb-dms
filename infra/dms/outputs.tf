output "migration_job" {
  value = google_database_migration_service_migration_job.rds_to_alloydb.migration_job_id
}

output "dms_user" {
  value = local.dms_user
}

output "dms_user_secret_id" {
  value = google_secret_manager_secret.dms_user.id
}
