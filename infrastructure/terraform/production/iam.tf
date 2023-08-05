## Instances' access to AWS resources

locals {
  instance_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Permissions",
        Effect = "Allow",
        Action = [
          "ec2:DescribeTags",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "instance_role" {
  provider = aws.london

  name               = "${local.name}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "instance_role_policy" {
  provider = aws.london

  name   = "${local.name}-policy"
  policy = local.instance_role_policy
}

resource "aws_iam_role_policy_attachment" "attach_instance_policy" {
  provider = aws.london

  role       = aws_iam_role.instance_role.name
  policy_arn = aws_iam_policy.instance_role_policy.arn
}


resource "aws_iam_instance_profile" "instance_profile" {
  provider = aws.london

  name = "${local.name}-profile"
  role = aws_iam_role.instance_role.name
}
