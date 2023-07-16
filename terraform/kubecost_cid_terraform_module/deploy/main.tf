# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

# Module instance for the pipeline module, to create the AWS pipeline resources
module "pipeline" {
  source = "../modules/pipeline"

  glue_crawler_schedule = ""
  custom_athena_workgroup = {
    create                             = true # Change to 'false' to not create a custom Athena Workgroup
    query_results_location_bucket_name = ""   # Add your query results bucket name
  }
}

# Module instances for the kubecost_s3_exporter module, to create IRSA and deploy the Kubecost S3 Exporter pod

# Example module instance for cluster with Helm invocation
module "cluster1" {

  # This is an example, to help you get started

  source = "../modules/kubecost_s3_exporter"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster1
    helm         = helm.us-east-1-111111111111-cluster1
  }

  cluster_arn                          = ""
  cluster_oidc_provider_arn            = ""
  kubecost_s3_exporter_container_image = ""
}

# Example module instance for cluster without Helm invocation
module "cluster2" {

  # This is an example, to help you get started

  source = "../modules/kubecost_s3_exporter"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster2
  }

  cluster_arn                          = ""
  cluster_oidc_provider_arn            = ""
  kubecost_s3_exporter_container_image = ""
}