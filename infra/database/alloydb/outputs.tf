# Consumed by the dms and tools stacks via terraform_remote_state.

output "cluster_id" {
  value = google_alloydb_cluster.dest.cluster_id
}

output "primary_ip" {
  value = google_alloydb_instance.primary.ip_address
}

output "postgres_secret_id" {
  value = google_secret_manager_secret.postgres.id
}
