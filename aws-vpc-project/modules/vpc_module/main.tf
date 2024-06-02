resource "aws_vpc" "nodeproject-vpc" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    "Name" = "${var.project}-${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nodeproject-vpc.id

  tags = {
    "Name" = "${var.project}-${var.env}-igw"
  }
}

resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.nodeproject-vpc.id
  cidr_block              = var.subnet-public1-config.cidr
  availability_zone       = var.subnet-public1-config.az
  map_public_ip_on_launch = true

  tags = {
    "Name" = "${var.project}-${var.env}-public1"
     "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.nodeproject-vpc.id
  cidr_block              = var.subnet-public2-config.cidr
  availability_zone       = var.subnet-public2-config.az
  map_public_ip_on_launch = true

  tags = {
    "Name" = "${var.project}-${var.env}-public2"
     "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.nodeproject-vpc.id
  cidr_block              = var.subnet-private1-config.cidr
  availability_zone       = var.subnet-private1-config.az
  map_public_ip_on_launch = false

  tags = {
    "Name" = "${var.project}-${var.env}-private1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.nodeproject-vpc.id
  cidr_block              = var.subnet-private2-config.cidr
  availability_zone       = var.subnet-private2-config.az
  map_public_ip_on_launch = false

  tags = {
    "Name" = "${var.project}-${var.env}-private2"
  }
}

resource "aws_eip" "nodeproject-eip-nat" {
  count = var.eip_enable ? 1 : 0
  domain = "vpc"
  
  tags = {
    "Name" = "${var.project}-${var.env}-eip-nat"
  }
}


resource "aws_nat_gateway" "nodeproject-natgw" {
  count = var.eip_enable ? 1 : 0

  allocation_id = aws_eip.nodeproject-eip-nat[0].id
  subnet_id     = aws_subnet.public1.id
  
  tags = {
    Name = "${var.project}-${var.env}-nat_gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_eip.nodeproject-eip-nat[0]]
}

resource "aws_route_table" "nodeproject-rt-public" {
  vpc_id = aws_vpc.nodeproject-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }


  tags = {
    Name = "${var.project}-${var.env}-rt-public"
  }
}


resource "aws_route_table" "nodeproject-rt-private" {
  count = var.eip_enable ? 1 : 0
  vpc_id = aws_vpc.nodeproject-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nodeproject-natgw[0].id
  }

  tags = {
    Name = "${var.project}-${var.env}-rt-private"
  }
}

resource "aws_route_table_association" "nodeproject-rt_subnet-assoc1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.nodeproject-rt-public.id
}

resource "aws_route_table_association" "nodeproject-rt_subnet-assoc2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.nodeproject-rt-public.id
}

resource "aws_route_table_association" "nodeproject-rt_subnet-assoc3" {
  count = var.eip_enable ? 1 : 0
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.nodeproject-rt-private[0].id
}

resource "aws_route_table_association" "nodeproject-rt_subnet-assoc4" {
  count = var.eip_enable ? 1 : 0
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.nodeproject-rt-private[0].id
}