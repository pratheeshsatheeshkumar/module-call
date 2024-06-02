

terraform {

  required_providers {

    aws = {

      source = "hashicorp/aws"

      version = "~> 5.33.0"
    }

  }
  /*
  backend "s3" {
    bucket = "nodeproject.pratheesh.online"
    key    = "terraform.tfstate"
    region = "ap-southeast-2"

  }
*/
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "project" = var.project
      "env"     = var.env
    }
  }

}

provider "tls" {
}

# Fetch EKS cluster details
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name
}

# Fetch EKS cluster authentication token
data "aws_eks_cluster_auth" "eks" {
  name = data.aws_eks_cluster.eks.name
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}
