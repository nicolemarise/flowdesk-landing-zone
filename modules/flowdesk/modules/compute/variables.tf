variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "key_name" {
  type = string
}

variable "ec2_sg_id" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "ec2_instance_profile_name" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "asg_min_size" {
  type = number
}

variable "asg_desired_capacity" {
  type = number
}

variable "asg_max_size" {
  type = number
}

variable "cpu_target_value" {
  type = number
}
