variable "project" {
  default = "demo"  
}
variable "env" {
  
}

variable "eip_enable" {
  type = bool
  default = true
}
variable "vpc_cidr_block" {}
variable "subnet-public1-config" {
  type = map(any)
  default = {
    cidr = "null"
    az   = "null"
  }
}
variable "subnet-public2-config" {
  type = map(any)
  default = {
    cidr = "null"
    az   = "null"
  }
}

variable "subnet-private1-config" {
  type = map(any)
  default = {
    cidr = "null"
    az   = "null"
  }
}
variable "subnet-private2-config" {
  type = map(any)
  default = {
    cidr = "null"
    az   = "null"
  }
}