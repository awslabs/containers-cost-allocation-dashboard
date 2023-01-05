# Required Inputs
locals {
  region                    = "<region>"                    # Example: "us-east-1"
  eks_iam_oidc_provider_arn = "<eks_iam_oidc_provider_arn>" # Example: "arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>"
  bucket_arn                = "<arn>"
  image                     = "<registry_url>/<repo>:<tag>"
  cluster_name              = "<cluster_name>" # Your EKS cluster name
}

# Optional Inputs
locals {
  k8s_config_path       = "~/.kube/config"
  k8s_namespace         = "kubecost-s3-exporter"
  k8s_service_account   = "kubecost-s3-exporter"
  k8s_create_namespace  = true
  image_pull_policy     = "Always"
  schedule              = "0 0 * * *"                                   # The kubecost-s3-exporter CronJob schedule, in cron format (UTC)
  kubecost_api_endpoint = "http://kubecost-cost-analyzer.kubecost:9090" # Change to your Kubecost endpoint if necessary
  granularity           = "hourly"
  k8s_labels            = [] # Example: ["app", "chart"]
}