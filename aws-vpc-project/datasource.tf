data "aws_availability_zones" "az" {
  state = "available"
}

data "aws_caller_identity" "current" {}
# Update kubeconfig
data "aws_eks_cluster_auth" "demo_cluster" {
  name = aws_eks_cluster.nodeproject_cluster.name
}

data "aws_eks_cluster" "eks_cluster" {
  name = aws_eks_cluster.nodeproject_cluster.name
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = data.aws_eks_cluster.eks_cluster.name
}




