module "vpc" {
  source         = "./modules/vpc_module"
  project        = var.project
  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  eip_enable     = false #This flag will avoid creating eip, natgw and private rt 
  subnet-public1-config = {
    cidr = var.nodeproject-public1-config.cidr
    az   = var.nodeproject-public1-config.az
  }

  subnet-private1-config = {
    cidr = var.nodeproject-private1-config.cidr
    az   = var.nodeproject-private1-config.az
  }
    subnet-public2-config = {
    cidr = var.nodeproject-public2-config.cidr
    az   = var.nodeproject-public2-config.az
  }

  subnet-private2-config = {
    cidr = var.nodeproject-private2-config.cidr
    az   = var.nodeproject-private2-config.az
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
  subnet_id                   = module.vpc.public1
  instance_count              = 0
  associate_public_ip_address = true

}
module "ec2-private" {
  source                      = "./modules/ec2"
  project                     = var.project
  env                         = var.env
  instance_name               = "backend-server"
  sg_id                       = aws_security_group.backend-sg.id
  subnet_id                   = module.vpc.private1
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
# Install kubectl and eksctl binaries

resource "null_resource" "install_kubectl_eksctl" {
  provisioner "local-exec" {
    command = "wget https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/linux/amd64/kubectl && chmod +x ./kubectl &&  mv ./kubectl /usr/local/bin/ && wget https://github.com/eksctl-io/eksctl/releases/download/v0.180.0/eksctl_Linux_amd64.tar.gz && tar xzf eksctl_Linux_amd64.tar.gz && chmod +x ./eksctl &&  mv ./eksctl /usr/local/bin/ && rm  eksctl_Linux_amd64.tar.gz"
  }
}

# Create EKS cluster
resource "aws_eks_cluster" "nodeproject_cluster" {
  name     = "${var.project}-${var.env}-Cluster"
  version  = "1.29"
  role_arn = "arn:aws:iam::905418455397:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS"

vpc_config {
    subnet_ids         = [module.vpc.private1,module.vpc.private2]
    security_group_ids = [aws_security_group.frontend-sg.id]
    endpoint_public_access = true
    public_access_cidrs = ["0.0.0.0/0"]
  }

}


#Example IAM Role for EKS Fargate Profile

resource "aws_iam_role" "fargate_role" {
  name = "eks-fargate-profile"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate_role.name
}
resource "aws_eks_fargate_profile" "fargate_profile" {
  cluster_name           = aws_eks_cluster.nodeproject_cluster.name
  fargate_profile_name   = "${var.project}-${var.env}-Fargate-Profile"
  pod_execution_role_arn = aws_iam_role.fargate_role.arn
  subnet_ids             = [module.vpc.private1,module.vpc.private2]

  selector {
    namespace = "${var.project}-${var.env}"
  }
}
resource "null_resource" "update_kube_config" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.project}-${var.env}-Cluster --region ap-southeast-2"
  }
}

# Deploy Sample App
resource "null_resource" "sample_app" {
  provisioner "local-exec" {
    command = "kubectl apply -f deployment.yaml"
  }
  depends_on = [aws_eks_cluster.nodeproject_cluster, null_resource.install_kubectl_eksctl]
}

resource "null_resource" "configure_iam_oidc_provider" {
  provisioner "local-exec" {
    command = <<-EOT
      export cluster_name=${var.project}-${var.env}-Cluster
      oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
      if ! aws iam list-open-id-connect-providers | grep -q $oidc_id; then
        eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
      fi
    EOT
  }
  depends_on = [aws_eks_cluster.nodeproject_cluster]
}

# Create IAM policy for ALB controller
resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy1"
  description = "IAM policy for AWS Load Balancer Controller"
  
  policy = file("${path.module}/iam_policy.json")
}
# Create IAM role for ALB controller
resource "aws_iam_role" "eks_cluster_service_role" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach IAM policy to ALB controller role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy_attachment" {
  role       = aws_iam_role.eks_cluster_service_role.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
}

resource "null_resource" "helm_repo_add" {
  provisioner "local-exec" {
    command = "helm repo add eks https://aws.github.io/eks-charts"
  }
  #depends_on = [aws_eks_cluster.nodeproject_cluster, data.external.install_kubectl_eksctl]
}



# Install the AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = "${var.project}-${var.env}-Cluster"
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
}