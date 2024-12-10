provider "aws" {
  region = "us-east-2"  # Choose your preferred region
}

# Create an IAM Role for the EKS cluster with the correct assume role policy
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Effect = "Allow"
      Sid    = ""
    }]
  })
}

# Attach the required policies to the IAM role for EKS
resource "aws_iam_role_policy_attachment" "eks_role_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
}

# Create VPC for EKS cluster
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create two subnets in different Availability Zones for high availability
resource "aws_subnet" "subnet" {
  count = 2
  vpc_id = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # Use CIDR subnetting
  availability_zone = element(["us-east-2a", "us-east-2b"], count.index) # Replace with AZs in your region
  map_public_ip_on_launch = true
  tags = {
    Name = "EKS-Subnet-${count.index}"
  }
}

# Create Security Group for the EKS cluster
resource "aws_security_group" "eks_security_group" {
  name        = "eks-security-group"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.main.id
}

# Create EKS Cluster
resource "aws_eks_cluster" "example" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids          = aws_subnet.subnet[*].id  # Use all subnet IDs
    security_group_ids  = [aws_security_group.eks_security_group.id]
  }
}
