# General locals
locals {
  name = "my_name" # This name will be prepended to different resources names in AWS and in K8s
}

# AWS resources, and K8s resources referenced in AWS resources
locals {
  region              = "<region>"   # Example: "us-east-1"
  eks_oidc_url        = "<oidc_url>" # Example: "arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>
  bucket_arn          = "<arn>"
  k8s_namespace       = "${local.name}-kubecost-s3-exporter"
  k8s_service_account = "${local.name}-kubecost-s3-exporter"
  k8s_labels          = [] # Example: ["app", "chart"]
}