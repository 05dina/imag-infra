
locals {
  engine_family = "postgres${split(".", local.env.db_version)[0]}"
}

module "rds-sg" {
  source = "terraform-aws-modules/security-group/aws//modules/postgresql"

  vpc_id              = module.vpc.vpc_id
  name                = "${terraform.workspace}-rds-sg"
  ingress_cidr_blocks = local.private_subnets

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

module "rds" {
  source = "terraform-aws-modules/rds/aws"

  create_db_instance              = true
  engine                          = "postgres"
  family                          = local.engine_family
  engine_version                  = local.env.db_version
  db_name                         = local.db_credentials["PGDATABASE"]
  username                        = local.db_credentials["PGUSERNAME"]
  password                        = local.db_credentials["PGPASSWORD"]
  allocated_storage               = local.env.db_storage
  instance_class                  = local.env.db_instance_class
  skip_final_snapshot             = true
  deletion_protection             = false
  identifier                      = "${terraform.workspace}-db-instance"
  subnet_ids                      = module.vpc.database_subnets
  vpc_security_group_ids          = [module.rds-sg.security_group_id]
  create_db_subnet_group          = true
  storage_encrypted               = false
  manage_master_user_password     = false
  db_subnet_group_name            = "${terraform.workspace}-db-subnet-group"
  db_subnet_group_use_name_prefix = false

  db_subnet_group_tags = {
    Name = "${terraform.workspace}-db-subnet-group"
  }

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "update_pgendpoint" {
  secret_id = data.aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    PGENDPOINT = module.rds.db_instance_endpoint
    PGPASSWORD = local.db_credentials["PGPASSWORD"]
    PGUSERNAME = local.db_credentials["PGUSERNAME"]
    PGDATABASE = local.db_credentials["PGDATABASE"]
  })

  depends_on = [module.rds]
}
