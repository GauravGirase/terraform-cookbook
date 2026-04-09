# count_example.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# ------------------------
# VPC
# ------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "my-vpc"
  }
}

# ------------------------
# Subnet (Public)
# ------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# ------------------------
# Internet Gateway
# ------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-igw"
  }
}

# ------------------------
# Route Table
# ------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ------------------------
# Security Group (SSH)
# ------------------------
resource "aws_security_group" "ssh" {
  name   = "allow-ssh"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------
# AMI (Latest Amazon Linux)
# ------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}

# ------------------------
# EC2 Instances (count)
# ------------------------
variable "instances" {
  default = ["web", "api", "worker"]
  #   default = ["api", "worker"]
}

resource "aws_instance" "app" {
  count = length(var.instances)

  ami           = "ami-048f4445314bcaa09"
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh.id]

  associate_public_ip_address = true

  tags = {
    Name = var.instances[count.index]
  }
}
