variable "project" {
  default = "demo"  
}
variable "env" {
  
}
variable "vpc_cidr_block" {}
variable "subnet-public-config" {
  type = map(any)
  default = {
    cidr = "null"
    az   = "null"
  }
}
variable "subnet-private-config" {
  type = map(any)
  default = {
    cidr = "null"
    az   = "null"
  }

}