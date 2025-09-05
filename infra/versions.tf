terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Configure remote state backend
  # Uncomment and configure if you want to store state remotely
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "voice-agent/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ai-voice-agent"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}