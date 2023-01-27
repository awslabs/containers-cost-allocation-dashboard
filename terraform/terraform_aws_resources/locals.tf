# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

# Required Inputs
locals {
  region                    = "<region>"                    # Example: "us-east-1"
  eks_iam_oidc_provider_arn = "<eks_iam_oidc_provider_arn>" # Example: "arn:aws:iam::<account_id>:oidc-provider/oidc.eks.<region>.amazonaws.com/id/<id>
  bucket_arn                = "<bucket_arn>"
}

# Optional Inputs
locals {
  k8s_namespace       = "kubecost-s3-exporter"
  k8s_service_account = "kubecost-s3-exporter"
  k8s_labels          = [] # Example: ["app", "chart"]
}