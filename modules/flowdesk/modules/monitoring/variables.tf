variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "asg_name" {
  type = string
}

variable "high_cpu_alarm_threshold" {
  type = number
}

variable "target_group_arn_suffix" {
  type = string
}

variable "lb_arn_suffix" {
  type = string
}

variable "db_instance_id" {
  type = string
}
