module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  vpc_cidr     = var.vpc_cidr
}

module "storage" {
  source = "./modules/storage"

  project_name               = var.project_name
  s3_bucket_name             = var.s3_bucket_name
  flowdesk_static_files_path = var.flowdesk_static_files_path
}

module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  vpc_id                    = module.network.vpc_id
  public_subnet_ids         = module.network.public_subnet_ids
  private_subnet_ids        = module.network.private_subnet_ids
  instance_type             = var.instance_type
  key_name                  = var.key_name
  ec2_sg_id                 = module.security.ec2_sg_id
  alb_sg_id                 = module.security.alb_sg_id
  ec2_instance_profile_name = module.security.ec2_instance_profile_name
  s3_bucket_name            = module.storage.bucket_name
  asg_min_size              = var.asg_min_size
  asg_desired_capacity      = var.asg_desired_capacity
  asg_max_size              = var.asg_max_size
  cpu_target_value          = var.cpu_target_value
}

module "database" {
  source = "./modules/database"

  project_name         = var.project_name
  private_subnet_ids   = module.network.private_subnet_ids
  rds_sg_id            = module.security.rds_sg_id
  db_instance_class    = var.db_instance_class
  db_engine_version    = var.db_engine_version
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_allocated_storage = var.db_allocated_storage
  db_multi_az          = var.db_multi_az
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name             = var.project_name
  aws_region               = var.aws_region
  asg_name                 = module.compute.asg_name
  high_cpu_alarm_threshold = var.high_cpu_alarm_threshold
  target_group_arn_suffix  = module.compute.target_group_arn_suffix
  lb_arn_suffix            = module.compute.lb_arn_suffix
  db_instance_id           = module.database.db_instance_id
}
