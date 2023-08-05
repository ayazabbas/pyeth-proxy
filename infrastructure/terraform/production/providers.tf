provider "aws" {
  region = "eu-west-2"
  alias  = "london"
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0, < 6.0.0"
    }
  }
}
