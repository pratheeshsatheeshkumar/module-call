

# Instance creation of zomato-prod-frontend

resource "aws_instance" "zomato-prod-frontend" {
  count = var.instance_count  
  ami                         = var.instance_ami
  associate_public_ip_address = var.associate_public_ip_address
  subnet_id                   = var.subnet_id
  instance_type               = var.instance_type
  key_name                    = "${var.project}-${var.env}-keypair"
  vpc_security_group_ids      = [var.sg_id]
  tags = {
    "Name" = "${var.project}-${var.env}-${var.instance_name}"
  }
/*
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/ubuntu/keys/aws_key")
    host        = self.public_ip
  }


  provisioner "file" {
    source      = "home/ubuntu/module-call/aws-vpc-project/apache_install.sh"
    destination = "/tmp/apache_install.sh"

  }

  provisioner "remote-exec" {

    inline = [
      "sudo chmod +x /tmp/apache_install.sh",
      "sudo /tmp/apache_install.sh"
    ]
  }
*/


}