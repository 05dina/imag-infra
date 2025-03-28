
module "vpc_cni_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${module.eks.cluster_name}-vpc-cni-irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"

  create          = true
  cluster_name    = "${terraform.workspace}-eks"
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa                              = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {

    coredns = {
      preserve          = true
      resolve_conflicts = "OVERWRITE"
      most_recent       = true
      timeouts          = { create = "30m", delete = "15m" }
    }

    vpc-cni = {
      preserve                 = true
      resolve_conflicts        = "NONE"
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }

    kube-proxy = {
      preserve          = false
      resolve_conflicts = "OVERWRITE"
      most_recent       = true
    }

    eks-pod-identity-agent = {
      preserve          = false
      resolve_conflicts = "OVERWRITE"
      most_recent       = true
    }
  }

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}
