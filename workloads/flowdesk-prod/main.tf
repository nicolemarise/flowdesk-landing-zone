terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "flowdesk-tfstate-763103709053"
    key          = "workloads/flowdesk-prod/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

data "terraform_remote_state" "org" {
  backend = "s3"
  config = {
    bucket = "flowdesk-tfstate-763103709053"
    key    = "organization/terraform.tfstate"
    region = "eu-west-1"
  }
}

locals {
  workloads_account_id = data.terraform_remote_state.org.outputs.account_ids["workloads"]
}

provider "aws" {
  region = "eu-west-1"

  assume_role {
    role_arn     = "arn:aws:iam::${local.workloads_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-flowdesk"
  }

  default_tags {
    tags = {
      Project     = "flowdesk"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}

module "flowdesk" {
  source = "../../modules/flowdesk"

  aws_region                 = "eu-west-1"
  availability_zones         = ["eu-west-1a", "eu-west-1b"]
  s3_bucket_name             = "flowdesk-static-${local.workloads_account_id}"
  flowdesk_static_files_path = "${path.module}/site"
  db_password                = var.db_password
}

output "alb_dns_name" {
  value = module.flowdesk.alb_dns_name
}

output "vpc_id" {
  value = module.flowdesk.vpc_id
}

output "s3_bucket_name" {
  value = module.flowdesk.s3_bucket_name
}

output "asg_name" {
  value = module.flowdesk.asg_name
}
