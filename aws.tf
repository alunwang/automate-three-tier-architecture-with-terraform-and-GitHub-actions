# Use AWS as the provider
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.AWS_REGION
}
