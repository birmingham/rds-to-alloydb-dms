variable "rds_engine_version" {
  description = "Major version; AWS picks the latest minor."
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.medium"
}
