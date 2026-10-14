# Inputs from the two network stacks. Apply network/gcp and network/aws first.

data "terraform_remote_state" "network_gcp" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/network/gcp"
  }
}

data "terraform_remote_state" "network_aws" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/network/aws"
  }
}

locals {
  net_gcp = data.terraform_remote_state.network_gcp.outputs
  net_aws = data.terraform_remote_state.network_aws.outputs
}
