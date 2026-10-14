variable "aws_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "aws_private_subnet_cidrs" {
  description = "Two private subnets in different AZs (an RDS subnet group needs two)."
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "aws_side_asn" {
  description = "Amazon-side ASN of the virtual private gateway."
  type        = number
  default     = 64512
}
