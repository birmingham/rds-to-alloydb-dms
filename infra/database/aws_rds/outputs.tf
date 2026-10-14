# Consumed by the dms and tools stacks via terraform_remote_state.

output "address" {
  value = aws_db_instance.source.address
}

output "port" {
  value = aws_db_instance.source.port
}

output "identifier" {
  value = aws_db_instance.source.identifier
}

output "admin_user" {
  value = local.rds_admin_user
}

output "admin_secret_id" {
  value = google_secret_manager_secret.admin.id
}
