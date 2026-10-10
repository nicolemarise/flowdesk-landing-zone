output "alb_dns_name" {
  description = "Public URL of the load balancer - open this in a browser to see Flowdesk live"
  value       = module.compute.alb_dns_name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.network.vpc_id
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS database"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket holding Flowdesk's static files"
  value       = module.storage.bucket_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_name
}
