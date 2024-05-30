variable "project" {
  default     = "oorja"
  description = "name of the project"

}

variable "env" {
  default     = "dev"
  description = "environment of the project"

}

variable "region" {
  default     = "ap-south-1"
  description = "aws region"
}

variable "instance_ami" {
 // default = "ami-0c84181f02b974bc3"
 default = "ami-0f58b397bc5c1f2e8"
}

variable "instance_type" {
  default = "t2.micro"
}
variable "sg_id" {
  type = string
}

variable "subnet_id" {
  
}

variable "instance_count" {
  
}

variable "associate_public_ip_address" {
  
}

variable "instance_name" {
 
}