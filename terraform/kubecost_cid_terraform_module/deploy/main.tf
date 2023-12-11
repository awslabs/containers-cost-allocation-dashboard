# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.26.0"
      configuration_aliases = [aws.pipeline, aws.eks]
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
  }
}

######################################
# Section 1 - AWS Pipeline Resources #
######################################

# Module instance for the pipeline module, to create the AWS pipeline resources
module "pipeline" {
  source = "../modules/pipeline"
}

#########################################################
# Section 2 - Data Collection Pod Deployment using Helm #
#########################################################

# Module instances for the kubecost_s3_exporter module, to create IRSA and deploy the K8s resources

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
  kubecost_s3_exporter_container_image = ""
}

####################################
# Section 3 - Quicksight Resources #
####################################

module "quicksight" {
  source = "../modules/quicksight"

  providers = {
    aws = aws.quicksight
  }

  glue_database_name = module.pipeline.glue_database_name
  glue_view_name     = module.pipeline.glue_view_name

  # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
  # Otherwise, remove the below field
  athena_workgroup_configuration = {
    query_results_location_bucket_name = ""
  }
}