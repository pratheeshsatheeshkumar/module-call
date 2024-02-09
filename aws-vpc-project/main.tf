module "vpc" {
  source = "../vpc_module"
  project = var.project
  env = var.env
  vpc_cidr_block = var.vpc_cidr_block
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
  
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
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


# Instance creation of zomato-prod-frontend

resource "aws_instance" "zomato-prod-frontend" {
  ami                         = var.instance_ami
  associate_public_ip_address = true
  subnet_id                   = module.vpc.public
  instance_type               = var.instance_type
  key_name                    = "${var.project}-${var.env}-keypair"
  vpc_security_group_ids      = [aws_security_group.frontend-sg.id]
  tags = {
    "Name" = "${var.project}-${var.env}-frontend"
  }

  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = file("/home/ubuntu/keys/aws_key")
    host = self.public_ip
  }
  
  
  provisioner "file" {
    source = "apache_install.sh"
    destination = "/tmp/apache_install.sh"
      
  }

  provisioner "remote-exec" {
       
    inline = [
      "sudo chmod +x /tmp/apache_install.sh",
      "sudo /tmp/apache_install.sh"
      ]  
  }
 
}


