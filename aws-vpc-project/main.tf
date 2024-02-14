module "vpc" {
  source         = "./modules/vpc_module"
  project        = var.project
  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  eip_enable     = true #This flag will avoid creating eip, natgw and private rt 
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
  source    = "./modules/ec2"
  project   = var.project
  env       = var.env
  instance_name = "frontend-server"
  sg_id     = aws_security_group.frontend-sg.id
  subnet_id = module.vpc.public
  instance_count = 2
  associate_public_ip_address = true

}
module "ec2-private" {
  source    = "./modules/ec2"
  project   = var.project
  env       = var.env
  instance_name = "backend-server"
  sg_id     = aws_security_group.backend-sg.id
  subnet_id = module.vpc.private
  instance_count = 2
  associate_public_ip_address = false

}



resource "null_resource" "write_publicip" {

  triggers = {
    instance_id = module.ec2.instance_id[0]
  }

  provisioner "local-exec" {
    command = "echo ssh -i /home/ubuntu/keys/aws_key ec2-user@${module.ec2.public_ip[0]} > out.txt"
  }
  # or we can use the command "terraform output > out.txt"


}
