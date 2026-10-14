output "tools_vm" {
  value = google_compute_instance.tools.name
}

output "zone" {
  value = google_compute_instance.tools.zone
}
