
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  azs  = local.azs
  cidr = local.env.cidr
  name = "${terraform.workspace}-vpc"

  create_igw                          = true
  enable_dns_support                  = true
  enable_dns_hostnames                = true
  enable_vpn_gateway                  = false
  enable_nat_gateway                  = true
  single_nat_gateway                  = false
  one_nat_gateway_per_az              = true
  create_multiple_public_route_tables = true

  public_subnets       = local.public_subnets
  public_subnet_names  = local.public_subnet_names
  private_subnets      = local.private_subnets
  private_subnet_names = local.private_subnet_names

  database_subnets                  = local.database_subnets
  database_subnet_names             = local.database_subnet_names
  create_database_subnet_group      = true
  create_database_nat_gateway_route = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}
