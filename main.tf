# Automatically fetch your current public IP
data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

# Locals (AZ selection)
locals {
  azs = length(var.azs) >= 2 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 2)
}


# VPC / Subnets / IGW / NATs / Route Tables
#################################################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "techcorp-vpc" }
}

# Public subnets (2)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "techcorp-public-subnet-${count.index + 1}" }
}

# Private subnets (2)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "techcorp-private-subnet-${count.index + 1}" }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "techcorp-igw" }
}

# Public route table + associations
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "techcorp-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# EIPs for NAT (one EIP per NAT)
resource "aws_eip" "nat_eip" {
  count  = 2
  domain = "vpc"

  tags = { Name = "techcorp-nat-eip-${count.index + 1}" }
}

# NAT Gateways (one per public subnet)
resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "techcorp-nat-gateway-${count.index + 1}" }

  depends_on = [aws_internet_gateway.main]
}

# Private route tables and associations (each private subnet -> its NAT in same index)
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = { Name = "techcorp-private-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#################################################
# Security Groups
#################################################
# Bastion SG - SSH only from allowed CIDRs
resource "aws_security_group" "bastion_sg" {
  name        = "techcorp-bastion-sg"
  description = "Bastion host security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks =["${chomp(data.http.myip.response_body)}/32"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-bastion-sg" }
}

# Web SG - HTTP/HTTPS from anywhere, SSH from bastion SG
resource "aws_security_group" "web_sg" {
  name        = "techcorp-web-sg"
  description = "Web servers security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from Bastion"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups  = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-web-sg" }
}

# DB SG - Postgres only from web SG, SSH from bastion SG
resource "aws_security_group" "db_sg" {
  name        = "techcorp-db-sg"
  description = "Database security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from Web"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-db-sg" }
}

# ALB SG - allow HTTP (and add 443 later if needed)
resource "aws_security_group" "alb_sg" {
  name        = "techcorp-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "techcorp-alb-sg" }
}

#################################################
# EC2: Bastion, Web (2), DB
#################################################
# Bastion (public subnet 1)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = var.keypair
  tags = { Name = "techcorp-bastion" }
}

# Elastic IP for bastion
resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = { Name = "techcorp-bastion-eip" }
}

# Web servers (two, one per private subnet)
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = false
  user_data              = file("${path.module}/user_data/web_server_setup.sh")
  key_name               = var.keypair

  tags = { Name = "techcorp-web-${count.index + 1}" }
}

# Database server (private subnet 1)
resource "aws_instance" "db" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  associate_public_ip_address = false
  user_data              = file("${path.module}/user_data/db_server_setup.sh")
  key_name               = var.keypair
  tags = { Name = "techcorp-db" }
}

#################################################
# ALB, Target Group, Listener
#################################################
resource "aws_lb" "alb" {
  name               = "techcorp-app-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = { Name = "techcorp-app-lb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "techcorp-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "techcorp-app-tg"
  }
}


# Register web instances to the target group
resource "aws_lb_target_group_attachment" "web_attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
