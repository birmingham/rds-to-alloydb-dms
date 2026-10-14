variable "tools_machine_type" {
  type    = string
  default = "e2-small"
}

variable "database_name" {
  description = "Application database created and loaded by db/bootstrap-source.sh."
  type        = string
  default     = "shop"
}
