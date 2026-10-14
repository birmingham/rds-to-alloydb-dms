terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Credentials come from the environment (AWS_PROFILE or the default chain).
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      project    = var.name
      managed-by = "terraform"
    }
  }
}
