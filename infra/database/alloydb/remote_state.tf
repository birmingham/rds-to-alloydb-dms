# Input: the VPC and Private Services Access range from network/gcp.

data "terraform_remote_state" "network_gcp" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/network/gcp"
  }
}

locals {
  net_gcp = data.terraform_remote_state.network_gcp.outputs
}
