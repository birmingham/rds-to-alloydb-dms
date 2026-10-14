resource "aws_db_subnet_group" "source" {
  name       = "${var.name}-source"
  subnet_ids = local.net_aws.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "PostgreSQL from GCP over the VPN"
  vpc_id      = local.net_aws.vpc_id

  # Gotcha #3: DMS connects from the AlloyDB PSA range, not from our GCP
  # subnet. Both need to be allowed.
  ingress {
    description = "AlloyDB (DMS replication) and the GCP tools VM"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.net_gcp.psa_cidr, local.net_gcp.tools_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Everything DMS needs on an RDS source. Static parameters take effect at
# instance creation; db/bootstrap-source.sh verifies them before loading data.
resource "aws_db_parameter_group" "pglogical" {
  name   = "${var.name}-pg${var.rds_engine_version}-pglogical"
  family = "postgres${var.rds_engine_version}"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pglogical"
    apply_method = "pending-reboot"
  }
  parameter {
    name  = "wal_sender_timeout"
    value = "0"
  }
  parameter {
    name         = "max_replication_slots"
    value        = "10"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_wal_senders"
    value        = "15"
    apply_method = "pending-reboot"
  }
  parameter {
    name         = "max_worker_processes"
    value        = "16"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "source" {
  identifier     = "${var.name}-source"
  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  username = local.rds_admin_user
  password = random_password.admin.result

  db_subnet_group_name   = aws_db_subnet_group.source.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.pglogical.name
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period    = 1
  auto_minor_version_upgrade = true
  apply_immediately          = true
  skip_final_snapshot        = true
  deletion_protection        = false
}
