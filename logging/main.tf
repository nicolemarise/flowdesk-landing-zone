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
    key          = "logging/terraform.tfstate"
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
  mgmt_account_id       = "763103709053"
  logarchive_account_id = data.terraform_remote_state.org.outputs.account_ids["logarchive"]
  trail_name            = "flowdesk-org-trail"
  trail_arn             = "arn:aws:cloudtrail:eu-west-1:${local.mgmt_account_id}:trail/${local.trail_name}"
  bucket_name           = "flowdesk-org-logs-${local.logarchive_account_id}"
}

provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  alias  = "logarchive"
  region = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.logarchive_account_id}:role/OrganizationAccountAccessRole"
  }
}

data "aws_organizations_organization" "current" {}

resource "aws_s3_bucket" "logs" {
  provider = aws.logarchive
  bucket   = local.bucket_name
}

resource "aws_s3_bucket_versioning" "logs" {
  provider = aws.logarchive
  bucket   = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  provider = aws.logarchive
  bucket   = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  provider                = aws.logarchive
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  provider = aws.logarchive
  bucket   = aws_s3_bucket.logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = 365
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

data "aws_iam_policy_document" "logs" {
  provider = aws.logarchive

  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.logs.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.logs.arn}/AWSLogs/${local.mgmt_account_id}/*",
      "${aws_s3_bucket.logs.arn}/AWSLogs/${data.aws_organizations_organization.current.id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyLogDeletion"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
    ]
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  provider   = aws.logarchive
  bucket     = aws_s3_bucket.logs.id
  policy     = data.aws_iam_policy_document.logs.json
  depends_on = [aws_s3_bucket_public_access_block.logs]
}

resource "aws_cloudtrail" "org" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.logs.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.logs]
}

output "log_bucket" {
  value = aws_s3_bucket.logs.id
}

output "trail_arn" {
  value = aws_cloudtrail.org.arn
}
