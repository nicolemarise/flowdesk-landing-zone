resource "aws_s3_bucket" "static_files" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "${var.project_name}-static-files"
  }
}

# No aws_s3_bucket_public_access_block here on purpose. New S3 buckets have
# all four Block Public Access settings ON by default, and the org SCP
# (flowdesk-deny-public-s3) prevents anyone changing them.

locals {
  content_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
  }
}

resource "aws_s3_object" "static_files" {
  for_each = fileset(var.flowdesk_static_files_path, "*")

  bucket       = aws_s3_bucket.static_files.id
  key          = each.value
  source       = "${var.flowdesk_static_files_path}/${each.value}"
  etag         = filemd5("${var.flowdesk_static_files_path}/${each.value}")
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), "application/octet-stream")
}
