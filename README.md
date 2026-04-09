# count vs for_each
## count
### 🚫 Why count can cause problems ?
- Index-based addressing is unstable
- Resources are identified like aws_instance.example[0], aws_instance.example[1], etc.
- If you remove or reorder items in the list, Terraform may:
  - Destroy and recreate resources unnecessarily
  - Shift indexes → causing unintended changes
- No meaningful names.

## ✅ What to use instead: for_each
- stable resource identity

## Here’s a real-world style scenario that shows exactly how count can quietly break things in production.
```bash
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
```
### Observation
**Initial state**
```bash
web: 13.232.189.246
api : 13.127.77.3
worker: 13.233.87.179
```
**Removed web**
```bash
variable "instances" {
  default = ["api", "worker"]
}
```
!["terraform-plan-output](/doc/images/count_plan_after_remove.png)
**Terraform plan output**
```bash
Plan: 0 to add, 2 to change, 1 to destroy.
```
**new state:**
```bash
web:(deleted)
api : 13.232.189.246
worker: 13.127.77.3
```

### ⚠️ Why this matters
Even though it looks like shifting, internally:
- web instance → 💀 destroyed
- api instance → 💀 destroyed, 🆕 new one created
- worker instance → 💀 destroyed, 🆕 new one created
### So you lose
- Instance IDs
- Public IPs
- Any ephemeral data

## for_each
```bash
# for_each_example.tf
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
# EC2 Instances (for_each)
# ------------------------
variable "instances" {
  default = {
    web    = "t3.micro"
    api    = "t3.micro"
    worker = "t3.micro"
  }
}

resource "aws_instance" "app" {
  for_each = var.instances

  ami           = "ami-048f4445314bcaa09"
  instance_type = each.value

  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh.id]

  associate_public_ip_address = true

  tags = {
    Name = each.key
  }
}

```
### Observation
**Initial state**
```bash
web: 3.111.214.47
api: 13.234.118.98
worker:  13.233.16.215
```
**Removed web**
```bash
variable "instances" {
  default = {
    api    = "t3.micro"
    worker = "t3.micro"
  }
}
```
!["terraform-plan-output](/doc/images/for_each_after_remove.png)
**Terraform plan output**
```bash
Plan: 0 to add, 0 to change, 1 to destroy.
```
**new state:**
```bash
web:(deleted)
api : 13.234.118.98
worker: 13.233.16.215
```
