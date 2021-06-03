# AWS with Terraform

provider "aws" {
  region = "us-east-2"
  profile = "default"
  shared_credentials_file = "~/.aws/credentials"
}

resource "aws_security_group" "Jenkins" {
  name = "Jenkins EC2 instance"
  description = "Security group for the Jenkins EC2 instance"
}

resource "aws_security_group_rule" "Jenkins_instance_ingress_port" {
  type = "ingress"
  from_port = 8080
  protocol = "tcp"
  security_group_id = aws_security_group.Jenkins.id
  source_security_group_id = aws_security_group.Jenkins_ELB.id
  to_port = 8080
}

resource "aws_security_group_rule" "Jenkins_instance_ingress_SSH_port" {
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
  from_port = 22
  protocol = "tcp"
  security_group_id = aws_security_group.Jenkins.id
  to_port = 22
}

resource "aws_security_group_rule" "Jenkins_instance_ingress_NFS_port" {
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
  from_port = 2049
  protocol = "tcp"
  security_group_id = aws_security_group.Jenkins.id
  to_port = 2049
}

resource "aws_security_group_rule" "Jenkins_instance_egress_all_ports" {
  type = "egress"
  cidr_blocks = ["0.0.0.0/0"]
  from_port = 0
  protocol = "tcp"
  security_group_id = aws_security_group.Jenkins.id
  to_port = 65535
}

resource "aws_security_group" "Jenkins_ELB" {
  name = "Jenkins ELB"
  description = "Security group for the Jenkins ELB"
}

resource "aws_security_group_rule" "Jenkins_ELB_ingress_HTTP_port" {
  type = "ingress"
  cidr_blocks = ["0.0.0.0/0"]
  from_port = 80
  protocol = "tcp"
  security_group_id = aws_security_group.Jenkins_ELB.id
  to_port = 80
}

resource "aws_security_group_rule" "Jenkins_ELB_egress_Jenkins_EC2_instance_Jenkins_port" {
  type = "egress"
  from_port = 8080
  protocol = "tcp"
  security_group_id = aws_security_group.Jenkins_ELB.id
  source_security_group_id = aws_security_group.Jenkins.id
  to_port = 8080
}

resource "aws_lb" "Jenkins" {
  name = "Jenkins"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.Jenkins_ELB.id]
  subnets = ["subnet-5927f830","subnet-b506eace","subnet-647c7e2e"]
  tags = {
    Environment = "Jenkins"
  }
}

resource "aws_lb_listener" "Jenkins" {
  load_balancer_arn = aws_lb.Jenkins.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.Jenkins.arn
  }
}

resource "aws_lb_target_group" "Jenkins" {
  name = "Jenkins"
  port = 8080
  protocol = "HTTP"
  vpc_id = "vpc-f224e69b"
}

resource "aws_launch_configuration" "Jenkins" {
  name = "Jenkins"
  image_id = "ami-0f43f748f2b2c8869"
  instance_type = "t2.medium"
  key_name = "aws_with_terraform"
  security_groups = [aws_security_group.Jenkins.id]
}

resource "aws_autoscaling_group" "Jenkins" {
  name = "Jenkins"
  max_size = 1
  min_size = 1
  default_cooldown = 30
  launch_configuration = aws_launch_configuration.Jenkins.name
  health_check_grace_period = 300
  health_check_type = "EC2"
  desired_capacity = 1
  vpc_zone_identifier = ["subnet-5927f830","subnet-b506eace","subnet-647c7e2e"]
  target_group_arns = [aws_lb_target_group.Jenkins.arn]
}
