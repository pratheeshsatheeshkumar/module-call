module "vpc" {
  source         = "./modules/vpc_module"
  project        = var.project
  env            = var.env
  vpc_cidr_block = var.vpc_cidr_block
  eip_enable     = true #This flag will avoid creating eip, natgw and private rt 
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

data "aws_key_pair" "existing_key_pair" {
  key_name = "${var.project}-${var.env}-keypair"
}

resource "aws_key_pair" "aws-keypair" {
  # Only create the key pair if it doesn't already exist
  count = length(data.aws_key_pair.existing_key_pair) == 0 ? 1 : 0

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




/*
# Install kubectl and eksctl binaries

resource "null_resource" "install_kubectl_eksctl" {
  provisioner "local-exec" {
    command = "wget https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/ && wget https://github.com/eksctl-io/eksctl/releases/download/v0.180.0/eksctl_Linux_amd64.tar.gz && tar xzf eksctl_Linux_amd64.tar.gz && chmod +x ./eksctl && sudo mv ./eksctl /usr/local/bin/ && rm  eksctl_Linux_amd64.tar.gz"
  }
}
*/
# Define the role to be attached EKS

resource "aws_iam_role" "AWS_EKS_role" {
  name = "ServiceRoleForAmazonEKS-${replace(formatdate("YYYYMMDDhhmmss", timestamp()), ":", "-")}"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Attach the CloudWatchFullAccess policy to EKS role
resource "aws_iam_role_policy_attachment" "eks__CloudWatchFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role       = aws_iam_role.AWS_EKS_role.name
}

resource "aws_iam_role_policy_attachment" "eks__AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.AWS_EKS_role.name
}

resource "aws_iam_role_policy_attachment" "eks__AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.AWS_EKS_role.name
}

resource "aws_iam_role_policy_attachment" "eks__AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.AWS_EKS_role.name
}

resource "aws_iam_role_policy_attachment" "eks__AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.AWS_EKS_role.name
}



resource "aws_eks_cluster" "eks" {
 
  name     = "${var.project}-${var.env}-cluster"
  version  = "1.29"
  role_arn = aws_iam_role.AWS_EKS_role.arn

enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  vpc_config {
    subnet_ids             = [module.vpc.public1, module.vpc.private2]
    security_group_ids     = [aws_security_group.frontend-sg.id]
    endpoint_public_access = true
    endpoint_private_access = true
    public_access_cidrs    = ["0.0.0.0/0"]
  }
}


######################### Node Group ############################
resource "aws_iam_role" "node_group_role" {
  name                  = lower(format("%s-node-group-role-${replace(formatdate("YYYYMMDDhhmmss", timestamp()), ":", "-")}", lower(aws_eks_cluster.eks.name)))
  path                  = "/"
  force_detach_policies = false
  max_session_duration  = 3600
  assume_role_policy    = jsonencode(
    {
      Statement = [
        {
          Action    = "sts:AssumeRole"
          Effect    = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "node_group__AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group__AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group__AmazonEC2RoleforSSM" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group__AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group__CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.node_group_role.id
}

resource "aws_iam_role_policy_attachment" "node_group__AmazonEC2FullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group__CloudWatchFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group__AmazonSSMFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group__AWSWAFReadOnlyAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AWSWAFReadOnlyAccess"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_eks_node_group" "node_group" {
  cluster_name         = aws_eks_cluster.eks.name
  force_update_version = true
  disk_size = 10
  capacity_type        = "ON_DEMAND"
  labels               = {
    "eks/cluster-name"   = aws_eks_cluster.eks.name
    "eks/nodegroup-name" = format("nodegroup_%s", lower(aws_eks_cluster.eks.name))
  }
  node_group_name = format("nodegroup_%s", lower(aws_eks_cluster.eks.name))
  node_role_arn   = aws_iam_role.node_group_role.arn

  subnet_ids = [module.vpc.private1,module.vpc.private2] 

  instance_types = ["t2.medium"]

  scaling_config {
    desired_size = local.desired_size
    max_size     = local.max_size
    min_size     = local.min_size
  }

  timeouts {
    create = "20m"
    update = "10m"
    delete = "15m"
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "null_resource" "update_kube_config" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.project}-${var.env}-cluster --region ap-southeast-2"
  }
   depends_on = [aws_eks_cluster.eks, aws_eks_node_group.node_group]
}

# ACM Policy
resource "aws_iam_policy" "alb_ingress_acm_policy" {
  name        = "AmazonACMFullAccess-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "Amazon ACM Full Access policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "acm:*",
        "Resource": "*"
      }
    ]
  })
}

# EC2 Policy
resource "aws_iam_policy" "alb_ingress_ec2_policy" {
  name        = "AmazonEC2FullAccess-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "Amazon EC2 Full Access policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "ec2:*",
        "Resource": "*"
      }
    ]
  })
}

# ELB Policy
resource "aws_iam_policy" "alb_ingress_elb_policy" {
  name        = "AmazonElasticLoadBalancingFullAccess-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "Amazon Elastic Load Balancing Full Access policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "elasticloadbalancing:*",
        "Resource": "*"
      }
    ]
  })
}

# IAM Policy for ALB Ingress
resource "aws_iam_policy" "alb_ingress_iam_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ec2:Describe*",
          "elasticloadbalancing:*",
          "iam:CreateServiceLinkedRole",
          "iam:GetServerCertificate",
          "iam:ListServerCertificates",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "tag:GetResources",
          "tag:TagResources",
          "waf:GetWebACL"
        ],
        "Resource": "*"
      }
    ]
  })
}

# Cognito Policy
resource "aws_iam_policy" "alb_ingress_cognito_policy" {
  name        = "AmazonCognitoPowerUser-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "Amazon Cognito Power User policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "cognito-idp:*",
        "Resource": "*"
      }
    ]
  })
}

# WAF Policy
resource "aws_iam_policy" "alb_ingress_waf_policy" {
  name        = "AWSWAFRegionalFullAccess-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "AWS WAF Regional Full Access policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "waf-regional:*",
        "Resource": "*"
      }
    ]
  })
}

# Tagging API Policy
resource "aws_iam_policy" "alb_ingress_tag_policy" {
  name        = "ResourceGroupsTaggingAPIReadOnlyAccess-${lower(aws_eks_cluster.eks.name)}"
  path        = "/"
  description = "Resource Groups Tagging API Read-Only Access policy for ALB ingress"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "tag:GetResources",
          "tag:TagResources"
        ],
        "Resource": "*"
      }
    ]
  })
}

# Create ALB ingress role
resource "aws_iam_role" "alb_ingress_role" {
  name = lower(format("%s-alb-ingress-role", aws_eks_cluster.eks.name))

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# Attach policies to ALB ingress role
resource "aws_iam_role_policy_attachment" "alb_ingress_acm_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_acm_policy.arn
}

resource "aws_iam_role_policy_attachment" "alb_ingress_ec2_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_ec2_policy.arn
}

resource "aws_iam_role_policy_attachment" "alb_ingress_elb_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_elb_policy.arn
}

resource "aws_iam_role_policy_attachment" "alb_ingress_iam_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_iam_policy.arn
}

resource "aws_iam_role_policy_attachment" "alb_ingress_cognito_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_cognito_policy.arn
}

resource "aws_iam_role_policy_attachment" "alb_ingress_waf_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_waf_policy.arn
}

resource "aws_iam_role_policy_attachment" "alb_ingress_tag_attachment" {
  role       = aws_iam_role.alb_ingress_role.name
  policy_arn = aws_iam_policy.alb_ingress_tag_policy.arn
}

# Create Helm release for ALB ingress controller
resource "helm_release" "alb_ingress_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "annotations.service.beta.kubernetes.io/aws-load-balancer-subnets"
    value = module.vpc.public1 // Specify your public subnet IDs here
  }


  depends_on = [
    aws_iam_role.alb_ingress_role,
    aws_eks_node_group.node_group
  ]
}

# Create Service Account for ALB ingress
resource "kubernetes_service_account" "alb_ingress_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
  }

  automount_service_account_token = true

  depends_on = [
    aws_iam_role.alb_ingress_role
  ]
}

# Role Binding for ALB ingress
resource "kubernetes_role_binding" "alb_ingress_rb" {
  metadata {
    name      = "alb-ingress-controller-rolebinding"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "alb-ingress-controller"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.alb_ingress_sa.metadata[0].name
    namespace = kubernetes_service_account.alb_ingress_sa.metadata[0].namespace
  }

  depends_on = [
    kubernetes_service_account.alb_ingress_sa
  ]
}
