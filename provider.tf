terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Any 6.x release; blocks a future 7.0 from breaking the code
    }
  }
}

provider "aws" {
  region = var.region
}
