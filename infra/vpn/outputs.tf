output "aws_vpn_connection_ids" {
  value = aws_vpn_connection.gcp[*].id
}

output "gcp_tunnels" {
  value = google_compute_vpn_tunnel.aws[*].name
}
