variable "region" {
  description = "AWS region to deploy into. The Kali AMI ID in main.tf only exists in us-east-2."
  type        = string
  default     = "us-east-2"
}

variable "public_subnet_cidr" {
  description = "Address range for the lab's public subnet (must be inside the VPC's 10.0.0.0/16)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "aws_key" {
  description = "Name of your EC2 key pair (EC2 -> Network & Security -> Key Pairs). Key pairs are per region. Set it with TF_VAR_aws_key."
  type        = string
}

variable "my_public_ip" {
  description = "Your home public IPv4 address (no /32). Only this IP can reach the lab. Set it with TF_VAR_my_public_ip - never commit it."
  type        = string

  validation {
    condition     = can(cidrhost("${var.my_public_ip}/32", 0))
    error_message = "my_public_ip must be a plain IPv4 address like 203.0.113.10 (no /32)."
  }
}
