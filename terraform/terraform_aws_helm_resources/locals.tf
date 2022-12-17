# General locals
locals {
  name = "my_name" # This name will be prepended to different resources names in AWS and in K8s
}

# AWS and K8s locals
locals {
  region              = "<region>"   # Example: "us-east-1"
  eks_oidc_url        = "<oidc_url>" # Example: "arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>"
  bucket              = "${local.name}-kubecost-data"
  k8s_config_path     = "~/.kube/config"
  k8s_namespace       = "${local.name}-kubecost-s3-exporter"
  k8s_service_account = "${local.name}-kubecost-s3-exporter"
}

# Kubecost S3 Exporter locals
locals {
  image_repository      = "udid/kubecost_cid"
  image_pull_policy     = "Always"
  schedule              = "@midnight"                                   # The kubecost-s3-exporter pod schedule, in cron format (UTC)
  kubecost_api_endpoint = "http://kubecost-cost-analyzer.kubecost:9090" # Change to your Kubecost endpoint if necessary
  cluster_id            = "cluster-one"                                 # Change to your EKS cluster name
  granularity           = "hourly"
  k8s_labels            = [] # Example: ["app", "chart"]
}