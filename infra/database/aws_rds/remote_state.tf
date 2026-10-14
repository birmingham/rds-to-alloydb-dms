# Inputs: AWS subnets from network/aws; the AlloyDB PSA range and tools
# subnet from network/gcp (for the security group).

data "terraform_remote_state" "network_aws" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/network/aws"
  }
}

data "terraform_remote_state" "network_gcp" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/network/gcp"
  }
}

locals {
  net_aws        = data.terraform_remote_state.network_aws.outputs
  net_gcp        = data.terraform_remote_state.network_gcp.outputs
  rds_admin_user = "dbadmin"
}
