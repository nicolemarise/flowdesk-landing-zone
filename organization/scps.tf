locals {
  approved_regions = ["eu-west-1", "eu-central-1", "us-east-1"]
}

# 1. Deny root user actions in member accounts
data "aws_iam_policy_document" "deny_root" {
  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }
  }
}

# 2. Restrict to approved regions (global services exempt)
data "aws_iam_policy_document" "region_restrict" {
  statement {
    sid    = "DenyOutsideApprovedRegions"
    effect = "Deny"
    not_actions = [
      "iam:*",
      "organizations:*",
      "route53:*",
      "route53domains:*",
      "cloudfront:*",
      "waf:*",
      "wafv2:*",
      "sts:*",
      "support:*",
      "budgets:*",
      "ce:*",
      "health:*",
      "trustedadvisor:*",
      "globalaccelerator:*",
      "shield:*",
      "account:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = local.approved_regions
    }
  }
}

# 3. Deny disabling or modifying CloudTrail and Config
data "aws_iam_policy_document" "protect_logging" {
  statement {
    sid    = "DenyCloudTrailTampering"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
    ]
    resources = ["*"]
  }
  statement {
    sid    = "DenyConfigTampering"
    effect = "Deny"
    actions = [
      "config:StopConfigurationRecorder",
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
      "config:PutConfigurationRecorder",
      "config:PutDeliveryChannel",
    ]
    resources = ["*"]
  }
}

# 4. Deny leaving the organization
data "aws_iam_policy_document" "deny_leave_org" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

# 5. Require encryption (RDS, EBS, S3)
data "aws_iam_policy_document" "require_encryption" {
  statement {
    sid       = "DenyUnencryptedRDS"
    effect    = "Deny"
    actions   = ["rds:CreateDBInstance", "rds:CreateDBCluster"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "rds:StorageEncrypted"
      values   = ["false"]
    }
  }
  statement {
    sid       = "DenyUnencryptedEBSVolumes"
    effect    = "Deny"
    actions   = ["ec2:CreateVolume"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "ec2:Encrypted"
      values   = ["false"]
    }
  }
  statement {
    sid       = "DenyUnencryptedS3Uploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["*"]
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["false"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256", "aws:kms"]
    }
  }
}

# 6. Deny public S3 (block changes to Block Public Access)
data "aws_iam_policy_document" "deny_public_s3" {
  statement {
    sid    = "DenyS3PublicAccessChanges"
    effect = "Deny"
    actions = [
      "s3:PutAccountPublicAccessBlock",
      "s3:PutBucketPublicAccessBlock",
      "s3:DeletePublicAccessBlock",
      "s3:PutBucketPolicy",
      "s3:PutBucketAcl",
    ]
    resources = ["*"]
  }
}

locals {
  scps = {
    deny-root-user     = data.aws_iam_policy_document.deny_root.json
    restrict-regions   = data.aws_iam_policy_document.region_restrict.json
    protect-logging    = data.aws_iam_policy_document.protect_logging.json
    deny-leave-org     = data.aws_iam_policy_document.deny_leave_org.json
    require-encryption = data.aws_iam_policy_document.require_encryption.json
    deny-public-s3     = data.aws_iam_policy_document.deny_public_s3.json
  }
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps
  name     = "flowdesk-${each.key}"
  type     = "SERVICE_CONTROL_POLICY"
  content  = each.value
}

resource "aws_organizations_policy_attachment" "workloads" {
  for_each  = local.scps
  policy_id = aws_organizations_policy.scp[each.key].id
  target_id = aws_organizations_organizational_unit.this["Workloads"].id
}
