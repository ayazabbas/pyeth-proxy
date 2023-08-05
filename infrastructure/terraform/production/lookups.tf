data "aws_ami" "ubuntu_london" {
  provider = aws.london

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230516"]
  }
}

data "aws_ami" "ubuntu_virginia" {
  provider = aws.virginia

  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230516"]
  }
}

data "aws_secretsmanager_secret" "secret" {
  provider = aws.london

  name = "prod/pyeth-proxy"
}

data "aws_secretsmanager_secret_version" "secret" {
  provider = aws.london

  secret_id = data.aws_secretsmanager_secret.secret.id
}
