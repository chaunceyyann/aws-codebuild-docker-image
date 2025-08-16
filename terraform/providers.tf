# aws-codebuild-docker-image/terraform/provider.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0" # Required for CodeBuild compute fleets
    }
  }
  required_version = ">= 1.6.6"

  backend "s3" {
    bucket         = "docker-image-4codebuild-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "docker-image-4codebuild-tfstate-lock"
  }
}

provider "aws" {
  region = var.aws_region
}
