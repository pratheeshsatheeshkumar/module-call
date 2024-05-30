

terraform {

  required_providers {

    aws = {

      source = "hashicorp/aws"

      version = "~> 5.33.0"
    }

  }

  backend "s3" {
    bucket = "nodeproject.pratheesh.online"
    key    = "terraform.tfstate"
    region = "ap-southeast-2"

  }

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


