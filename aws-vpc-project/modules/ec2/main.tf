

# Instance creation of zomato-prod-frontend

resource "aws_instance" "zomato-prod-frontend" {
  count = var.instance_count  
  ami                         = var.instance_ami
  associate_public_ip_address = var.associate_public_ip_address
  subnet_id                   = var.subnet_id
  instance_type               = var.instance_type
  user_data = <<EOF
  #!/bin/bash


echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
echo "LANG=en_US.utf-8" >> /etc/environment
echo "LC_ALL=en_US.utf-8" >> /etc/environment


yum install httpd php git amazon-efs-utils -y
systemctl restart httpd.service

git clone https://github.com/Fujikomalan/aws-elb-site.git  /var/website/
cp -r  /var/website/*  /var/www/html/
chown -R apache:apache /var/www/html/*


systemctl restart httpd.service
systemctl enable httpd.service


EOF

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