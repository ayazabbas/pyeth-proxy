variable "alb_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for load balancer (usually public)"
}

variable "asg_desired_capacity" {
  type = number
}

variable "asg_max_size" {
  type = number
}

variable "asg_min_size" {
  type = number
}

variable "asg_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for autoscaling group instances (usually private)"
}

variable "certificate_arn" {
  type        = string
  default     = null
  description = "Certificate ARN for HTTPS listener"
}

variable "ec2_image_id" {
  type        = string
  description = "ID of the Amazon Machine Image to use for ec2 instances"
}

variable "ec2_instance_type" {
  type = string
}

variable "environment" {
  type = string
}

variable "health_check_healthy_threshold" {
  type = number
}

variable "health_check_interval" {
  type = number
}

variable "health_check_path" {
  type = string
}

variable "health_check_unhealthy_threshold" {
  type = number
}

variable "health_check_timeout" {
  type = number
}

variable "iam_instance_profile_arn" {
  type = string
}

variable "key_name" {
  type        = string
  description = "Name of ec2 key-pair, used to SSH to the instances"
}

variable "name" {
  type = string
}

variable "port" {
  type        = number
  default     = null
  description = "Port the application server is listening on"
}

variable "project" {
  type        = string
  description = "Added to resource tags. Helps to keep track of which project a resource belongs to"
}

variable "user_data" {
  type        = string
  description = "Base-64 encoded userdata script to run when launching the instances"
}

variable "volume_size" {
  type    = number
  default = 8
}

variable "volume_type" {
  type    = string
  default = "gp3"
}

variable "volume_iops" {
  type    = number
  default = 3000
}

variable "volume_throughput" {
  type    = number
  default = 150
}

variable "vpc_id" {
  type = string
}
