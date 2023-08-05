locals {
  common_tags = {
    application = var.name
    project     = var.project
    environment = var.environment
    Terraform   = "true"
  }
}

## SECURITY GROUPS

module "alb_security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "~> 4.9.0"
  name        = "${var.name}-sg-alb"
  description = "ALB Security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = local.common_tags

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outgoing"
    }
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "Allow HTTP incoming"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow HTTPS incoming"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "ec2_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.9.0"

  name        = "${var.name}-sg-ec2"
  description = "EC2 Security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = local.common_tags

  ingress_with_source_security_group_id = [
    {
      from_port                = var.port
      to_port                  = var.port
      protocol                 = "tcp"
      description              = "Allow incoming from ALB"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
      description = "Allow all outgoing"
    }
  ]
}


## LOAD BALANCER

module "application_alb" {
  source                = "terraform-aws-modules/alb/aws"
  version               = "~> 8.6.0"
  name                  = var.name
  vpc_id                = var.vpc_id
  subnets               = var.alb_subnet_ids
  create_security_group = false
  security_groups       = [module.alb_security_group.security_group_id]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = var.certificate_arn
      target_group_index = 0
    }
  ]

  # automatically redirect http to https
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0

      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]

  target_groups = [
    {
      name             = "${var.name}-tg"
      backend_port     = var.port
      backend_protocol = "HTTP"
      health_check = {
        enabled             = true
        interval            = var.health_check_interval
        path                = var.health_check_path
        port                = "traffic-port"
        healthy_threshold   = var.health_check_healthy_threshold
        unhealthy_threshold = var.health_check_unhealthy_threshold
        timeout             = var.health_check_timeout
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
  ]

  tags = local.common_tags
}


## AUTOSCALING GROUP

module "asg" {
  name    = var.name
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.9.0"

  use_name_prefix                 = false
  min_size                        = var.asg_min_size
  max_size                        = var.asg_max_size
  desired_capacity                = var.asg_desired_capacity
  health_check_type               = "ELB"
  vpc_zone_identifier             = var.asg_subnet_ids
  security_groups                 = [module.ec2_security_group.security_group_id]
  target_group_arns               = [module.application_alb.target_group_arns[0]]
  ignore_desired_capacity_changes = true
  default_cooldown                = 15

  # Life Cycle
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 1
      checkpoint_percentages = [30, 60, 100]
      instance_warmup        = 1
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  launch_template_name            = "${var.name}-lt"
  launch_template_use_name_prefix = false
  launch_template_description     = "Launch template for ${var.name}"
  update_default_version          = true
  user_data                       = var.user_data
  iam_instance_profile_arn        = var.iam_instance_profile_arn

  image_id          = var.ec2_image_id
  instance_type     = var.ec2_instance_type
  key_name          = var.key_name
  ebs_optimized     = true
  enable_monitoring = true

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/sda1"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = var.volume_size
        volume_type           = var.volume_type
        volume_iops           = var.volume_iops
        volume_throughput     = var.volume_throughput
      }
    }
  ]

  termination_policies = [
    "OldestLaunchTemplate",
    "OldestInstance"
  ]

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  # Autoscaling
  scaling_policies = {
    avg-cpu-policy-greater-than-50 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 60
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    }
  }

  tags = local.common_tags

  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { Name = var.name }
    }
  ]
}
