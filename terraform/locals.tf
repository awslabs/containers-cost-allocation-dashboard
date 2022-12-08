locals {
  name = "kubecost_cid"
  bucket = "kubecost-cid"
  k8s_namespace = "kubecost-cid"
  k8s_service_account = "kubecost-cid2"
  eks_oidc_url = "arn:aws:iam::742719403826:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/842C756C29C13E7A449FA13B06A228BB"
}