locals {
  # secrets
  secrets = jsondecode(data.aws_secretsmanager_secret_version.secret.secret_string)

  # regionally common attributes
  asg_max_size                     = 4
  asg_min_size                     = 2
  asg_desired_capacity             = 2
  ec2_instance_type                = "t3.micro"
  environment                      = "prod"
  health_check_interval            = 10
  health_check_healthy_threshold   = 2
  health_check_path                = "/health"
  health_check_unhealthy_threshold = 2
  health_check_timeout             = 3
  name                             = "pyeth-proxy"
  port                             = 8000
  project                          = "pyeth-proxy"
  iam_instance_profile_arn         = aws_iam_instance_profile.instance_profile.arn

  user_data = base64encode(templatefile("templates/user_data.sh.tpl",
    {
      ECR_REGION         = "eu-west-2",
      ECR_URL            = "858463413507.dkr.ecr.eu-west-2.amazonaws.com"
      GITHUB_SSH_KEY     = replace(local.secrets["GITHUB_SSH_KEY"], "\\n", "\n")
      RPC_PROVIDERS_HTTP = local.secrets["RPC_PROVIDERS_HTTP"],
      TIMEOUT_SECONDS    = local.secrets["TIMEOUT_SECONDS"],
      LOKI_URL           = local.secrets["LOKI_URL"],
      LOKI_USER          = local.secrets["LOKI_USER"]
      LOKI_PASSWORD      = local.secrets["LOKI_PASSWORD"]
    }
  ))
}

module "pyeth_proxy_london" {
  source = "../modules/aws_alb_asg"

  providers = {
    aws = aws.london
  }

  # common attributes
  asg_max_size                     = local.asg_max_size
  asg_min_size                     = local.asg_min_size
  asg_desired_capacity             = local.asg_desired_capacity
  ec2_instance_type                = local.ec2_instance_type
  environment                      = local.environment
  health_check_interval            = local.health_check_interval
  health_check_healthy_threshold   = local.health_check_healthy_threshold
  health_check_path                = local.health_check_path
  health_check_unhealthy_threshold = local.health_check_unhealthy_threshold
  health_check_timeout             = local.health_check_timeout
  iam_instance_profile_arn         = local.iam_instance_profile_arn
  name                             = local.name
  port                             = local.port
  project                          = local.project
  user_data                        = local.user_data

  # region-specific attributes
  alb_subnet_ids  = ["subnet-025328860f3b10d5e", "subnet-0c150d5e42963fdb5"]
  asg_subnet_ids  = ["subnet-025328860f3b10d5e", "subnet-0c150d5e42963fdb5"]
  certificate_arn = "arn:aws:acm:eu-west-2:858463413507:certificate/89e81164-94ef-4d83-9d33-359fd200914d"
  ec2_image_id    = data.aws_ami.ubuntu_london.id
  key_name        = "admin"
  vpc_id          = "vpc-02cecdf97567b71cf"
}

module "pyeth_proxy_virginia" {
  source = "../modules/aws_alb_asg"

  providers = {
    aws = aws.virginia
  }

  # common attributes
  asg_max_size                     = local.asg_max_size
  asg_min_size                     = local.asg_min_size
  asg_desired_capacity             = local.asg_desired_capacity
  ec2_instance_type                = local.ec2_instance_type
  environment                      = local.environment
  health_check_interval            = local.health_check_interval
  health_check_healthy_threshold   = local.health_check_healthy_threshold
  health_check_path                = local.health_check_path
  health_check_unhealthy_threshold = local.health_check_unhealthy_threshold
  health_check_timeout             = local.health_check_timeout
  iam_instance_profile_arn         = local.iam_instance_profile_arn
  name                             = local.name
  port                             = local.port
  project                          = local.project
  user_data                        = local.user_data

  # region-specific attributes
  alb_subnet_ids  = ["subnet-0f116f35b433e6b96", "subnet-08b851bd304ffeb10"]
  asg_subnet_ids  = ["subnet-0f116f35b433e6b96", "subnet-08b851bd304ffeb10"]
  certificate_arn = "arn:aws:acm:us-east-1:858463413507:certificate/3c020457-0980-4c06-9fa8-50c9479e7aeb"
  ec2_image_id    = data.aws_ami.ubuntu_virginia.id
  key_name        = "admin"
  vpc_id          = "vpc-0c29b164f612d8d0e"
}

resource "aws_route53_record" "pyeth_proxy_london" {
  provider = aws.london

  name           = "pyeth-proxy.ayazabbas.com"
  set_identifier = "London"
  type           = "A"
  zone_id        = "Z052053634X6YAOHSYMDU"

  alias {
    evaluate_target_health = true
    name                   = "dualstack.${module.pyeth_proxy_london.lb_dns_name}"
    zone_id                = module.pyeth_proxy_london.lb_zone_id
  }

  latency_routing_policy {
    region = "eu-west-2"
  }
}

resource "aws_route53_record" "pyeth_proxy_virginia" {
  provider = aws.virginia

  name           = "pyeth-proxy.ayazabbas.com"
  set_identifier = "Virginia"
  type           = "A"
  zone_id        = "Z052053634X6YAOHSYMDU"

  alias {
    evaluate_target_health = true
    name                   = "dualstack.${module.pyeth_proxy_virginia.lb_dns_name}"
    zone_id                = module.pyeth_proxy_virginia.lb_zone_id
  }

  latency_routing_policy {
    region = "us-east-1"
  }
}
