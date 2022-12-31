# Required Inputs
locals {
  region       = "<region>"   # Example: "us-east-1"
  eks_oidc_url = "<oidc_url>" # Example: "arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>
  bucket_arn   = "<arn>"
}

# Optional Inputs
locals {
  k8s_namespace       = "kubecost-s3-exporter"
  k8s_service_account = "kubecost-s3-exporter"
  k8s_labels          = [] # Example: ["app", "chart"]
}