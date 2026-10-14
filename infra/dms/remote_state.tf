# Inputs: the source (database/aws_rds), the destination (database/alloydb),
# and the VPC AlloyDB uses to reach RDS (network/gcp).

data "terraform_remote_state" "network_gcp" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/network/gcp"
  }
}

data "terraform_remote_state" "rds" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/database/aws_rds"
  }
}

data "terraform_remote_state" "alloydb" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/database/alloydb"
  }
}

locals {
  net_gcp  = data.terraform_remote_state.network_gcp.outputs
  rds      = data.terraform_remote_state.rds.outputs
  alloydb  = data.terraform_remote_state.alloydb.outputs
  dms_user = "dms_user"
}
