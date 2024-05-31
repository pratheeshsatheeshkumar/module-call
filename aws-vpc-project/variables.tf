variable "project" {
  default     = "nodeproject"
  description = "name of the project"
}

variable "env" {
  default     = "dev"
  description = "environment of the project"
}

variable "region" {
  default     = "ap-southeast-2"
  description = "aws region"
}

variable "instance_ami" {
  default = "ami-0c84181f02b974bc3"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "vpc_cidr_block" {
  default = "172.17.0.0/16"
}

variable "nodeproject-public1-config" {
  type = map(any)
  default = {
    cidr = "172.17.0.0/18"
    az   = "ap-southeast-2a"
  }
}


variable "nodeproject-public2-config" {
  type = map(any)
  default = {
    cidr = "172.17.64.0/18"
    az   = "ap-southeast-2b"
  }
}

variable "nodeproject-private1-config" {
  type = map(any)
  default = {
    cidr = "172.17.128.0/18"
    az   = "ap-southeast-2a"
  }
}
variable "nodeproject-private2-config" {
  type = map(any)
  default = {
    cidr = "172.17.192.0/18"
    az   = "ap-southeast-2b"
  }
}
variable "ports" {
  type    = list(string)
  default = [80, 443, 22]

}

locals {
  subnets = length(data.aws_availability_zones.az.names)
  desired_size = 2
  max_size = 2
  min_size = 2
}

