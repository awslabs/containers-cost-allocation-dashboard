# AWS resources
locals {
  name         = "kubecost-cid"
  bucket       = "kubecost-cid"
  eks_oidc_url = "arn:aws:iam::742719403826:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/842C756C29C13E7A449FA13B06A228BB"
}

# K8s resources referenced in AWS resources
locals {
  k8s_namespace       = local.name
  k8s_service_account = local.name
  k8s_labels          = ["app", "chart"]
}