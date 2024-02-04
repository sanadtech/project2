

#----------------------------------------------------------
# ACS730 - Week 3 - Terraform Introduction
#
# Build EC2 Instances
#
#----------------------------------------------------------

#  Define the provider
provider "aws" {
  region = "us-east-1"
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Data block to retrieve the default VPC id
data "aws_vpc" "default" {
  default = true
}

resource "aws_default_vpc" "default" {}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "us-east-1a"

  tags = {
    Name = "Default subnet for us-east-1a"
  }
}

resource "aws_subnet" "publicSubnet" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = var.cidr
  tags = merge(
    local.default_tags, {
      Name = "${local.name_prefix}-public-subnet"
    }
  )
}

# Define tags locally
locals {
  default_tags = merge(module.globalvars.default_tags, { "env" = var.env })
  prefix       = module.globalvars.prefix
  name_prefix  = "${local.prefix}-${var.env}"
}

# Retrieve global variables from the Terraform module
module "globalvars" {
  source = "../modules/globalvars"
}

# Reference subnet provisioned by 01-Networking 
resource "aws_instance" "my_amazon" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.my_key.key_name
  iam_instance_profile        = "LabInstanceProfile"
  vpc_security_group_ids             = [aws_security_group.my_sg.id]
  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-Amazon-Linux"
    }
  )
}


# Adding SSH key to Amazon EC2
resource "aws_key_pair" "my_key" {
  key_name   = local.name_prefix
  public_key = file("${local.name_prefix}.pub")
}

# Security Group
resource "aws_security_group" "my_sg" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "HTTP from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "port 8080 custom TCP"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "port 8081 custom TCP"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "port 8082 custom TCP"
    from_port        = 8082
    to_port          = 8082
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-sg"
    }
  )
}

# Define ECR repo to store database images
resource "aws_ecr_repository" "database" {
  name         = "docker-${var.env}-containers-database-repo"
  force_delete = true
  tags = {
    Name = "docker-${var.env}-containers-database-repo"
  }
}

# Define ECR repo to store application images
resource "aws_ecr_repository" "application" {
  name         = "docker-${var.env}-containers-application-repo"
  force_delete = true
  tags = {
    Name = "docker-${var.env}-containers-application-repo"
  }
}

##resource "aws_security_group" "alb" {
  ##name        = "alb"
  ##description = "Allow traffic from the internet to the ALB"

  ##ingress {
    ##from_port   = 80
    ##to_port     = 80
    ##protocol    = "tcp"
    ##cidr_blocks = ["0.0.0.0/0"]
  ##}
##}

##resource "aws_alb" "mylb" {
  ##name            = "${var.env}-application-load-balancer"
  ##internal        = false
  ##security_groups = [aws_security_group.alb.id, data.terraform_remote_state.sg.outputs.ec2_sg_id]
  ##subnets         = [data.terraform_remote_state.networking.outputs.public_subnet, data.terraform_remote_state.networking.outputs.default_az_1]
  ##tags = {
    ##Name = "${var.env}-application-load-balancer"
  ##}
##}

# Elastic IP
resource "aws_eip" "static_eip" {
  instance = aws_instance.my_amazon.id
  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-eip"
    }
  )
}
