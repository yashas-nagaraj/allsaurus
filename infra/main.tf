# 1. NETWORK (VPC)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name = "allsaurus-vpc"
  cidr = "10.0.0.0/16"
  azs             = ["ap-south-1a", "ap-south-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  public_subnet_tags = { "kubernetes.io/role/elb" = 1 }
}

# 2. COMPUTE (EKS CLUSTER)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = "allsaurus-cluster"
  cluster_version = "1.29"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  eks_managed_node_groups = {
    defaults = { instance_types = ["t3.small"] } # Critical: t3.small for stability [cite: 51]
    worker_group_1 = { min_size = 2, max_size = 3, desired_size = 2 }
  }
}

# 3. FIREWALL (Allow EKS to talk to RDS)
resource "aws_security_group" "rds_sg" {
  name        = "allsaurus-rds-sg"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # The "Secret Handshake" [cite: 106]
  }
}

# 4. STORAGE (RDS Database)
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  identifier = "allsaurus-db"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name  = "stranger_db"
  username = "admin"
  password = "strangerpassword" # In production, use Variables!
  port     = "3306"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets
  skip_final_snapshot = true
  publicly_accessible = false
}

output "rds_endpoint" { value = module.db.db_instance_address }
output "cluster_name" { value = module.eks.cluster_name }
