# Shared by every stack (each stack keeps an identical copy; CI checks they
# match). Values come from infra/common.tfvars via scripts/tf.sh.

variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "state_bucket" {
  description = "GCS bucket holding every stack's Terraform state."
  type        = string
}

variable "state_prefix" {
  description = "State path prefix; each stack lives at <state_prefix>/<stack path>."
  type        = string
  default     = "rds-to-alloydb-dms"
}

variable "name" {
  description = "Name prefix for every resource in both clouds."
  type        = string
  default     = "dms-lab"
}

variable "gcp_region" {
  type    = string
  default = "us-west1"
}

variable "gcp_zone" {
  type    = string
  default = "us-west1-a"
}

variable "aws_region" {
  type    = string
  default = "us-west-2"
}
