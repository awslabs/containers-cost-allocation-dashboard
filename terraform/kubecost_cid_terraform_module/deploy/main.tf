# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

# Module instance for the pipeline module, to create the AWS pipeline resources
module "pipeline" {
  source = "../modules/pipeline"

  aws_profile           = ""
  aws_region            = ""
  glue_crawler_schedule = ""
}

# Module instances for the kubecost_s3_exporter module, to create IRSA and deploy the Kubecost S3 Exporter pod
module "cluster1" {
  source = "../modules/kubecost_s3_exporter"

  aws_profile                          = ""
  aws_region                           = ""
  cluster_arn                          = ""
  cluster_context                      = ""
  cluster_oidc_provider_arn            = ""
  kubecost_s3_exporter_container_image = ""
}