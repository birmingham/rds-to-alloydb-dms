variable "gcp_subnet_cidr" {
  description = "Subnet for the tools VM. Advertised to AWS over BGP."
  type        = string
  default     = "10.20.0.0/24"
}

variable "psa_address" {
  description = "Start of the Private Services Access range AlloyDB lives in."
  type        = string
  default     = "10.60.0.0"
}

variable "psa_prefix" {
  description = "Prefix length of the Private Services Access range (/24 or larger)."
  type        = number
  default     = 20
}

variable "gcp_router_asn" {
  description = "Cloud Router BGP ASN (private range, must differ from the AWS side ASN)."
  type        = number
  default     = 65534
}
