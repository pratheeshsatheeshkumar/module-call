

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

provider "kubernetes" {
  host                   = aws_eks_cluster.nodeproject_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.nodeproject_cluster.certificate_authority[0].data)
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}