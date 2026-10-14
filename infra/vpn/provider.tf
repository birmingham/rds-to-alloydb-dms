terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
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
