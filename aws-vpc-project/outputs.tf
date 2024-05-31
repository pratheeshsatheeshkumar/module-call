output "public_ip" {
  value = module.ec2.public_ip

}
output "public_key" {
  value = tls_private_key.rsa.public_key_openssh
}

output "endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}
