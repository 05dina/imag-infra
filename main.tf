#
data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret" "db_secret" {
  name = "db_credentials"
}

data "aws_secretsmanager_secret_version" "db_secrets" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id
}

data "aws_availability_zones" "available" { state = "available" }

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db_secrets.secret_string)
  azs            = slice(data.aws_availability_zones.available.names, 0, local.env.zones_numbers)

  yaml             = yamldecode(file("config.yaml"))
  env              = lookup(local.yaml.environments, var.environment, {})
  public_subnets   = [for i in range(local.env.zones_numbers) : cidrsubnet(local.env.cidr, local.env.cidr_subnet_bits, i + (local.env.zones_numbers * 0))]
  private_subnets  = [for i in range(local.env.zones_numbers) : cidrsubnet(local.env.cidr, local.env.cidr_subnet_bits, i + (local.env.zones_numbers * 1))]
  database_subnets = [for i in range(local.env.zones_numbers) : cidrsubnet(local.env.cidr, local.env.cidr_subnet_bits, i + (local.env.zones_numbers * 2))]

  private_subnet_names  = [for i in range(local.env.zones_numbers) : "${terraform.workspace}-private-subnet${i + 1}"]
  public_subnet_names   = [for i in range(local.env.zones_numbers) : "${terraform.workspace}-public-subnet${i + 1}"]
  database_subnet_names = [for i in range(local.env.zones_numbers) : "${terraform.workspace}-database-subnet${i + 1}"]
}
