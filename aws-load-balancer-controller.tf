
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  alias = "eks"

  host                   = data.aws_eks_cluster.this.endpoint
  token                  = data.aws_eks_cluster_auth.this.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
}

provider "helm" {
  alias = "eks"

  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  }
}

resource "aws_iam_policy" "aws_lb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
}

resource "aws_iam_role" "aws_lb_controller_role" {
  name = "${module.eks.cluster_name}-aws-lb-controller"

  assume_role_policy = templatefile("${path.module}/roles/aws-load-balancer-controller.json.tpl", {
    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_provider     = module.eks.oidc_provider
  })
}

resource "aws_iam_policy_attachment" "aws_lb_controller_attach" {
  name       = "aws-lb-controller-attach"
  policy_arn = aws_iam_policy.aws_lb_controller_policy.arn
  roles      = [aws_iam_role.aws_lb_controller_role.name]
}

resource "kubernetes_service_account" "aws_lb_controller_sa" {
  provider = kubernetes.eks

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_lb_controller_role.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  provider = helm.eks

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.11.0"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_lb_controller_sa.metadata[0].name
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    kubernetes_service_account.aws_lb_controller_sa,
    aws_iam_policy_attachment.aws_lb_controller_attach
  ]
}
