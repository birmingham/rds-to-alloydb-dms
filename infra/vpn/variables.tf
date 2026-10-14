variable "tunnel_inside_cidrs" {
  description = "Four /30s from 169.254.0.0/16 (avoid AWS-reserved 169.254.0-5.0/30 and 169.254.169.252/30)."
  type        = list(string)
  default     = ["169.254.21.0/30", "169.254.21.4/30", "169.254.22.0/30", "169.254.22.4/30"]
}
