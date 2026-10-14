variable "alloydb_database_version" {
  description = "Must be the same major version as the RDS source or newer."
  type        = string
  default     = "POSTGRES_16"
}

variable "alloydb_cpu_count" {
  type    = number
  default = 2
}

variable "alloydb_availability_type" {
  description = "REGIONAL (HA, what DMS documents) or ZONAL (cheaper)."
  type        = string
  default     = "REGIONAL"
}
