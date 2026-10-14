# Inputs: the subnet (network/gcp), both database endpoints, and the three
# Secret Manager secrets the VM is allowed to read.

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

data "terraform_remote_state" "dms" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${var.state_prefix}/dms"
  }
}

locals {
  net_gcp = data.terraform_remote_state.network_gcp.outputs
  rds     = data.terraform_remote_state.rds.outputs
  alloydb = data.terraform_remote_state.alloydb.outputs
  dms     = data.terraform_remote_state.dms.outputs

  secrets = {
    rds-admin        = local.rds.admin_secret_id
    alloydb-postgres = local.alloydb.postgres_secret_id
    dms-user         = local.dms.dms_user_secret_id
  }
}
