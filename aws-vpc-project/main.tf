module "vpc" {
  source         = "./modules/vpc_module"
  project        = var.project
  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  eip_enable     = false #This flag will avoid creating eip, natgw and private rt 
  subnet-public-config = {
    cidr = var.nodeproject-public1-config.cidr
    az   = var.nodeproject-public1-config.az
  }

  subnet-private-config = {
    cidr = var.nodeproject-private1-config.cidr
    az   = var.nodeproject-private1-config.az
  }
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


/*resource "local_file" "private_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "aws_key.pem"
}
*/
/*===Imported public key to aws and saved private key localy using a provisioner===*/

resource "aws_key_pair" "aws-keypair" {
  key_name   = "${var.project}-${var.env}-keypair"
  public_key = tls_private_key.rsa.public_key_openssh
  provisioner "local-exec" {
    command = "echo \"${tls_private_key.rsa.private_key_pem}\" > ./aws_key.pem ; chmod 400 ./aws_key.pem"
  }
  tags = {
    "Name" = "${var.project}-${var.env}-keypair"
  }
}


#Creation of security group for nodeproject-frontend

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

#Creation of security group for nodeproject-bastion

resource "aws_security_group" "bastion-sg" {
  name_prefix = "${var.project}-${var.env}-bastion-sg-"
  description = "allow ssh traffic"
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
  source                      = "./modules/ec2"
  project                     = var.project
  env                         = var.env
  instance_name               = "frontend-server"
  sg_id                       = aws_security_group.frontend-sg.id
  subnet_id                   = module.vpc.public
  instance_count              = 0
  associate_public_ip_address = true

}
module "ec2-private" {
  source                      = "./modules/ec2"
  project                     = var.project
  env                         = var.env
  instance_name               = "backend-server"
  sg_id                       = aws_security_group.backend-sg.id
  subnet_id                   = module.vpc.private
  instance_count              = 0
  associate_public_ip_address = false

}



/*resource "null_resource" "write_publicip" {

  triggers = {
    instance_id = module.ec2.instance_id[0]
  }

  provisioner "local-exec" {
    command = "echo ssh -i ./aws_key.pem ec2-user@${module.ec2.public_ip[0]} > out.txt"
  }
  # or we can use the command "terraform output > out.txt"


}
*/

resource "null_resource" "install_kubectl_eksctl" {
  provisioner "local-exec" {
    command = <<-EOT
      wget https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/linux/amd64/kubectl && chmod +x ./kubectl &&  mv ./kubectl /usr/local/bin/
      wget https://github.com/eksctl-io/eksctl/releases/download/v0.180.0/eksctl_Linux_amd64.tar.gz && tar xzf eksctl_Linux_amd64.tar.gz && chmod +x ./eksctl &&  mv ./eksctl /usr/local/bin/ && rm  eksctl_Linux_amd64.tar.gz
    EOT
  }
}
resource "null_resource" "create_eks_cluster" {
  provisioner "local-exec" {
    command = <<-EOT
      eksctl create cluster --name demo-cluster --version 1.29 --region ${var.region} --fargate
      aws eks update-kubeconfig --name demo-cluster --region ${var.region}
    EOT
  }
  depends_on = [null_resource.install_kubectl_eksctl]
}
resource "null_resource" "create_fargate_profile" {
  provisioner "local-exec" {
    command = <<-EOT
      eksctl create fargateprofile --cluster demo-cluster --region ${var.region} --name alb-sample-app --namespace game-2048
    EOT
  }
  depends_on = [null_resource.create_eks_cluster]
}
resource "null_resource" "deploy_2048_app" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/examples/2048/2048_full.yaml
    EOT
  }
  depends_on = [null_resource.create_fargate_profile]
}
resource "null_resource" "configure_iam_oidc_provider" {
  provisioner "local-exec" {
    command = <<-EOT
      export cluster_name=demo-cluster
      oidc_id=$(aws eks describe-cluster --name $cluster_name  --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
      if ! aws iam list-open-id-connect-providers | grep -q $oidc_id; then
        eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
      fi
    EOT
  }
  depends_on = [null_resource.create_eks_cluster]
}
resource "null_resource" "setup_alb_controller" {
  provisioner "local-exec" {
    command = <<-EOT
      curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
      aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
      eksctl create iamserviceaccount --cluster=demo-cluster --namespace=kube-system --name=aws-load-balancer-controller --role-name AmazonEKSLoadBalancerControllerRole --attach-policy-arn=arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy --approve
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update eks
      helm install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace kube-system --set clusterName=demo-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=${var.region} --set vpcId=${module.vpc.vpc_id}
    EOT
  }
  depends_on = [null_resource.configure_iam_oidc_provider]
}

