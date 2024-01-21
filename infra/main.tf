terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

locals {
  main_name = "ecs20240121"
}

#########################################
# VPC
#########################################

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id

  availability_zone = "ap-northeast-1a"
  cidr_block        = "10.0.1.0/24"
}

#########################################
# Internet Gateway
#########################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "main" {
  route_table_id         = aws_route_table.main.id
  gateway_id             = aws_internet_gateway.main.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "main" {
  route_table_id = aws_route_table.main.id
  subnet_id      = aws_subnet.main.id
}

#########################################
# Security Groups
#########################################

resource "aws_security_group" "nlb" {
  name   = "${local.main_name}-sg-nlb"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "app" {
  name   = "${local.main_name}-sg-app"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "nlb_ingress" {
  security_group_id = aws_security_group.nlb.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "nlb_egress" {
  security_group_id = aws_security_group.nlb.id

  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "app_ingress_nlb" {
  security_group_id = aws_security_group.app.id

  referenced_security_group_id = aws_security_group.nlb.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "app_ingress_self" {
  security_group_id = aws_security_group.app.id

  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "app_egress" {
  security_group_id = aws_security_group.app.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

#########################################
# NLB
#########################################

resource "aws_lb" "main" {
  name               = "${local.main_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.nlb.id]
  subnets            = [aws_subnet.main.id]
}

resource "aws_lb_target_group" "main" {
  name                 = "${local.main_name}-target-group"
  port                 = 80
  protocol             = "TCP"
  vpc_id               = aws_vpc.main.id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    interval            = 10
    port                = "traffic-port"
    protocol            = "TCP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.main.arn
    type             = "forward"
  }
}

#########################################
# ECS
#########################################

resource "aws_ecs_cluster" "main" {
  name = "${local.main_name}-ecs"
}

resource "aws_service_discovery_http_namespace" "namespace" {
  name = "${local.main_name}-namespace"
}

#########################################
# Output
#########################################

output "nlb_dns_name" {
  value = aws_lb.main.dns_name
}
