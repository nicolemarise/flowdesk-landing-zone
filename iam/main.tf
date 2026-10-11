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
    key          = "iam/terraform.tfstate"
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
  mgmt_account_id      = "763103709053"
  workloads_account_id = data.terraform_remote_state.org.outputs.account_ids["workloads"]
  deployer_role_name   = "flowdesk-terraform-deployer"
}

provider "aws" {
  region = "eu-west-1"
  assume_role {
    role_arn     = "arn:aws:iam::${local.workloads_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-iam-bootstrap"
  }
}

# Trust: only the management-account Terraform user may assume this role.
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.mgmt_account_id}:user/terraform-admin"]
    }
  }
}

data "aws_iam_policy_document" "deployer" {
  statement {
    sid       = "RegionalServicesInEuWest1"
    effect    = "Allow"
    actions   = ["ec2:*", "elasticloadbalancing:*", "autoscaling:*", "rds:*", "cloudwatch:*", "s3:*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["eu-west-1"]
    }
  }

  statement {
    sid       = "KmsRead"
    effect    = "Allow"
    actions   = ["kms:DescribeKey", "kms:ListAliases"]
    resources = ["*"]
  }

  statement {
    sid    = "KmsOnlyThroughRdsAndEc2"
    effect = "Allow"
    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RetireGrant",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.eu-west-1.amazonaws.com", "ec2.eu-west-1.amazonaws.com"]
    }
  }

  statement {
    sid    = "ManageFlowdeskRolesOnly"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.workloads_account_id}:role/flowdesk-*"]
  }

  statement {
    sid       = "AttachOnlyS3ReadOnly"
    effect    = "Allow"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = ["arn:aws:iam::${local.workloads_account_id}:role/flowdesk-*"]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
    }
  }

  statement {
    sid    = "ManageFlowdeskInstanceProfiles"
    effect = "Allow"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
    ]
    resources = ["arn:aws:iam::${local.workloads_account_id}:instance-profile/flowdesk-*"]
  }

  statement {
    sid       = "PassFlowdeskRolesToEc2"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.workloads_account_id}:role/flowdesk-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "ServiceLinkedRoles"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "autoscaling.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "rds.amazonaws.com",
      ]
    }
  }

  statement {
    sid    = "NeverThese"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "organizations:*",
      "account:*",
      "cloudtrail:*",
      "config:*",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "CannotModifyItself"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${local.workloads_account_id}:role/${local.deployer_role_name}",
      "arn:aws:iam::${local.workloads_account_id}:policy/${local.deployer_role_name}",
    ]
  }
}

resource "aws_iam_policy" "deployer" {
  name   = local.deployer_role_name
  policy = data.aws_iam_policy_document.deployer.json
}

resource "aws_iam_role" "deployer" {
  name                 = local.deployer_role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "deployer" {
  role       = aws_iam_role.deployer.name
  policy_arn = aws_iam_policy.deployer.arn
}

output "deployer_role_arn" {
  value = aws_iam_role.deployer.arn
}
