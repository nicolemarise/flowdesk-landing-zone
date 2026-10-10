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
    key          = "organization/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-1"
}

variable "emails" {
  type        = map(string)
  description = "Unique email per member account"
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "config-multiaccountsetup.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id
  ous     = toset(["Security", "Infrastructure", "Workloads"])

  accounts = {
    security   = { name = "flowdesk-security", ou = "Security" }
    logarchive = { name = "flowdesk-log-archive", ou = "Security" }
    shared     = { name = "flowdesk-shared-services", ou = "Infrastructure" }
    workloads  = { name = "flowdesk-workloads", ou = "Workloads" }
  }
}

resource "aws_organizations_organizational_unit" "this" {
  for_each  = local.ous
  name      = each.key
  parent_id = local.root_id
}

resource "aws_organizations_account" "this" {
  for_each          = local.accounts
  name              = each.value.name
  email             = var.emails[each.key]
  parent_id         = aws_organizations_organizational_unit.this[each.value.ou].id
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = true

  lifecycle {
    ignore_changes = [role_name]
  }
}

output "root_id" {
  value = local.root_id
}

output "ou_ids" {
  value = { for k, v in aws_organizations_organizational_unit.this : k => v.id }
}

output "account_ids" {
  value = { for k, v in aws_organizations_account.this : k => v.id }
}
