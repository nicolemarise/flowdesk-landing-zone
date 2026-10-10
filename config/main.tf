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
    key          = "config/terraform.tfstate"
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

data "terraform_remote_state" "logging" {
  backend = "s3"
  config = {
    bucket = "flowdesk-tfstate-763103709053"
    key    = "logging/terraform.tfstate"
    region = "eu-west-1"
  }
}

locals {
  accounts    = data.terraform_remote_state.org.outputs.account_ids
  bucket_name = data.terraform_remote_state.logging.outputs.log_bucket
}

# Management account (default credentials)
provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "security"
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.accounts["security"]}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "logarchive"
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.accounts["logarchive"]}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "shared"
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.accounts["shared"]}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias  = "workloads"
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.accounts["workloads"]}:role/OrganizationAccountAccessRole"
  }
}

module "config_management" {
  source      = "../modules/config-recorder"
  bucket_name = local.bucket_name
  providers   = { aws = aws }
}

module "config_security" {
  source      = "../modules/config-recorder"
  bucket_name = local.bucket_name
  providers   = { aws = aws.security }
}

module "config_logarchive" {
  source      = "../modules/config-recorder"
  bucket_name = local.bucket_name
  providers   = { aws = aws.logarchive }
}

module "config_shared" {
  source      = "../modules/config-recorder"
  bucket_name = local.bucket_name
  providers   = { aws = aws.shared }
}

module "config_workloads" {
  source      = "../modules/config-recorder"
  bucket_name = local.bucket_name
  providers   = { aws = aws.workloads }
}
