# DMS objects. Terraform creates them in NOT_STARTED state; the lifecycle
# (demote -> verify -> start -> promote) runs from scripts/dms.sh so each
# step is deliberate and observable.

resource "google_database_migration_service_connection_profile" "source" {
  location              = var.gcp_region
  connection_profile_id = "${var.name}-source-rds"
  # DMS rejects "special characters" such as parentheses in display names;
  # letters, digits, spaces and hyphens are fine.
  display_name = "RDS PostgreSQL ${var.aws_region}"

  postgresql {
    host     = local.rds.address
    port     = local.rds.port
    username = local.dms_user
    password = random_password.dms_user.result

    # Required by the API: the database DMS connects to first. DMS still
    # migrates every database on the instance (except template0/1, rdsadmin).
    database = "postgres"

    # RDS for PostgreSQL 15+ forces SSL by default. REQUIRED encrypts without
    # verifying the server certificate; traffic is also inside IPsec.
    ssl {
      type = "REQUIRED"
    }
  }
}

resource "google_database_migration_service_connection_profile" "destination" {
  location              = var.gcp_region
  connection_profile_id = "${var.name}-dest-alloydb"
  display_name          = "AlloyDB ${local.alloydb.cluster_id}"

  postgresql {
    alloydb_cluster_id = local.alloydb.cluster_id
  }
}

resource "google_database_migration_service_migration_job" "rds_to_alloydb" {
  location         = var.gcp_region
  migration_job_id = "${var.name}-rds-to-alloydb"
  display_name     = "RDS PostgreSQL to AlloyDB"
  type             = "CONTINUOUS"

  source      = google_database_migration_service_connection_profile.source.name
  destination = google_database_migration_service_connection_profile.destination.name

  # AlloyDB reaches RDS through this VPC: PSA peering -> Cloud Router -> HA VPN.
  vpc_peering_connectivity {
    vpc = local.net_gcp.network_id
  }

  performance_config {
    dump_parallel_level = "OPTIMAL"
  }
}
