module "vpc" {
  source         = "./modules/vpc_module"
  project        = var.project
  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  eip_enable =  false #This flag will avoid creating eip, natgw and private rt 
  subnet-public-config = {
    cidr = var.teevra-dev-public1-config.cidr
    az   = var.teevra-dev-public1-config.az
  }

  subnet-private-config = {
    cidr = var.teevra-dev-private1-config.cidr
    az   = var.teevra-dev-private1-config.az
  }
}


resource "aws_key_pair" "aws-keypair" {
  key_name   = "${var.project}-${var.env}-keypair"
  public_key = file("/home/ubuntu/keys/aws_key.pub")
  tags = {
    "Name" = "${var.project}-${var.env}-keypair"
  }
}


#Creation of security group for zomato-frontend

resource "aws_security_group" "frontend-sg" {
  name_prefix = "${var.project}-${var.env}-frontend-sg-"
  description = "allow http, https and ssh traffic"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = toset(var.ports)
    content {
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    #security_groups = [aws_security_group.zomato-prod-bastion-sg.id]
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

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name" = "${var.project}-${var.env}-frontend-sg"
  }
}

#Creation of security group for zomato-bastion

resource "aws_security_group" "bastion-sg" {
  name_prefix = "${var.project}-${var.env}-bastion-sg-"
  description = "allow http, https and ssh traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port        = 22
    to_port          = 22
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

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name" = "${var.project}-${var.env}-bastion-sg"
  }
}

#creation of backend security group

resource "aws_security_group" "backend-sg" {
  name_prefix = "${var.project}-${var.env}-backend-sg-"
  description = "allow sql and ssh traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend-sg.id]


  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    "Name" = "${var.project}-${var.env}-backend-sg"
  }
}

module "ec2" {
  source         = "./modules/ec2"
  project        = var.project
  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
}



resource "null_resource" "write_publicip" {

triggers = {
  instance_id = aws_instance.zomato-prod-frontend.public_ip
}

  provisioner "local-exec" {
    command = "echo ssh -i /home/ubuntu/keys/aws_key ec2-user@${aws_instance.zomato-prod-frontend.public_ip} > out.txt"
  }
#or we can use the command "terraform output > out.txt"

  
}
