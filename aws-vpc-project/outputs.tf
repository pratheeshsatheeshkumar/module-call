output "public_ip" {
  value = module.ec2.public_ip

}
output "public_key" {
  value = tls_private_key.rsa.public_key_openssh
}
