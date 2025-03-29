
# AWS Provider
terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    random = { source = "hashicorp/random" }
  }
}

terraform {
  backend "s3" {}
}

provider "aws" {
  region = var.region
}
