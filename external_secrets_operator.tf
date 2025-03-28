
resource "kubernetes_namespace" "demo1" {
  provider = kubernetes.eks

  metadata {
    name = "demo1"
  }

  depends_on = [
    module.eks,
    helm_release.aws_load_balancer_controller
  ]
}

resource "aws_iam_policy" "demo1_external_secrets_policy" {
  name        = "Demo1ExternalSecretsPolicy"
  path        = "/"
  description = "Permite acceso al secreto db_credentials desde el namespace demo1"

  policy = templatefile("${path.module}/policies/demo1_external_secrets_policy.json", {
    account_id = data.aws_caller_identity.current.account_id
    region     = var.region
  })
}

resource "aws_iam_role" "demo1_external_secrets_role" {
  name = "${module.eks.cluster_name}-demo1-external-secrets"

  assume_role_policy = templatefile("${path.module}/roles/demo1_external_secrets.tpl", {
    oidc_provider_arn = module.eks.oidc_provider_arn
    oidc_provider     = module.eks.oidc_provider
    service_account   = "external-secrets-sa"
    namespace         = "demo1"
  })

  depends_on = [kubernetes_namespace.demo1]
}

resource "aws_iam_policy_attachment" "demo1_external_secrets_attach" {
  name       = "attach-demo1-external-secrets"
  policy_arn = aws_iam_policy.demo1_external_secrets_policy.arn
  roles      = [aws_iam_role.demo1_external_secrets_role.name]
}

resource "kubernetes_service_account" "external_secrets_sa" {
  provider = kubernetes.eks

  metadata {
    name      = "external-secrets-sa"
    namespace = "demo1"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.demo1_external_secrets_role.arn
    }
  }

  depends_on = [
    kubernetes_namespace.demo1
  ]
}

resource "helm_release" "external_secrets" {
  provider = helm.eks

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.15.0"
  namespace  = "demo1"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.external_secrets_sa.metadata[0].name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  depends_on = [
    kubernetes_service_account.external_secrets_sa,
    aws_iam_policy_attachment.demo1_external_secrets_attach,
    helm_release.aws_load_balancer_controller
  ]
}
