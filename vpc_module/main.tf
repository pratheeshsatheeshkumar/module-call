resource "aws_vpc" "zomato-prod-vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    "Name" = "${var.project}-${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.zomato-prod-vpc.id

  tags = {
    "Name" = "${var.project}-${var.env}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.zomato-prod-vpc.id
  cidr_block              = var.subnet-public-config.cidr
  availability_zone       = var.subnet-public-config.az
  map_public_ip_on_launch = true

  tags = {
    "Name" = "${var.project}-${var.env}-public1"
  }
}


resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.zomato-prod-vpc.id
  cidr_block              = var.subnet-private-config.cidr
  availability_zone       = var.subnet-private-config.az
  map_public_ip_on_launch = false

  tags = {
    "Name" = "${var.project}-${var.env}-private1"
  }
}

resource "aws_eip" "zomato-prod-eip-nat" {
  domain = "vpc"
  tags = {
    "Name" = "${var.project}-${var.env}-eip-nat"
  }
}


resource "aws_nat_gateway" "zomato-prod-natgw" {
  allocation_id = aws_eip.zomato-prod-eip-nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project}-${var.env}-nat_gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "zomato-prod-rt-public" {
  vpc_id = aws_vpc.zomato-prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }


  tags = {
    Name = "${var.project}-${var.env}-rt-public"
  }
}


resource "aws_route_table" "zomato-prod-rt-private" {
  vpc_id = aws_vpc.zomato-prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.zomato-prod-natgw.id
  }

  tags = {
    Name = "${var.project}-${var.env}-rt-private"
  }
}

resource "aws_route_table_association" "zomato-prod-rt_subnet-assoc1" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.zomato-prod-rt-public.id
}

resource "aws_route_table_association" "zomato-prod-rt_subnet-assoc2" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.zomato-prod-rt-public.id
}

resource "aws_route_table_association" "zomato-prod-rt_subnet-assoc3" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.zomato-prod-rt-private.id
}