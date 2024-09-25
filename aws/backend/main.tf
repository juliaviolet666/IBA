provider "aws" {
  region = "us-east-1"
}


terraform {
  backend "s3" {
    bucket         = "bucket-petrova"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "DynamoDB"
    encrypt        = true
  }
}


resource "aws_vpc" "vpc-petrova" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "vpc-petrova"
  }
}

resource "aws_subnet" "public-petrova" {
  vpc_id                  = aws_vpc.vpc-petrova.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-petrova"
  }
}

resource "aws_subnet" "private-petrova" {
  vpc_id            = aws_vpc.vpc-petrova.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private-petrova"
  }
}

resource "aws_internet_gateway" "igw-petrova" {
  vpc_id = aws_vpc.vpc-petrova.id

  tags = {
    Name = "igw-petrova"
  }
}

resource "aws_route_table" "rt-public-petrova" {
  vpc_id = aws_vpc.vpc-petrova.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-petrova.id
  }
  tags = {
    Name = "rt-public-petrova"
  }
}

resource "aws_route_table_association" "rta-public-petrova" {
  subnet_id      = aws_subnet.public-petrova.id
  route_table_id = aws_route_table.rt-public-petrova.id
}

resource "aws_ecr_repository" "ecr-petrova" {
  name = "ecr-petrova"
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "eks-petrova"
  cluster_version = "1.30"

  vpc_id                         = aws_vpc.vpc-petrova.id
  subnet_ids                     = [aws_subnet.private-petrova.id, aws_subnet.public-petrova.id]
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    ng-petrova = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t2.micro"]

      min_size     = 1
      max_size     = 2
      desired_size = 2
    }
  }
}
