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

module "pipeline" {
  source = "../modules/pipeline"
}

#########################################################
# Section 2 - Data Collection Pod Deployment using Helm #
#########################################################

#                                  #
# Clusters in Account 111111111111 #
#                                  #

# Clusters in Region us-east-1 #

module "us-east-1-111111111111-cluster1" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster1
    helm         = helm.us-east-1-111111111111-cluster1
  }

  cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "https://kubecost-eks-cost-analyzer.kubecost-eks"
  connection_timeout                   = 5
  kubecost_allocation_api_read_timeout = 30
  tls_verify                           = "no"
  kubecost_ca_certificate_secret_name  = "kubecost"
  kubecost_ca_certificate_secrets      = module.pipeline.kubecost_ca_cert_secret
  kubecost_ephemeral_volume_size       = "100Mi"
  backfill_period_days                 = 5
}

module "us-east-1-111111111111-cluster2" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster2
    helm         = helm.us-east-1-111111111111-cluster2
  }

  cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  namespace                            = "kubecost-s3-exporter-2"
  service_account                      = "kubecost-s3-exporter-2"
  kubecost_allocation_api_paginate     = "Yes"
}

# Clusters in Region us-east-2 #

module "us-east-2-111111111111-cluster1" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-111111111111-cluster1
    helm         = helm.us-east-2-111111111111-cluster1
  }

  cluster_arn                                      = "arn:aws:eks:us-east-2:111111111111:cluster/cluster1"
  kubecost_s3_exporter_container_image             = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_s3_exporter_container_image_pull_policy = "IfNotPresent"
  kubecost_s3_exporter_pod_schedule                = "0 0 * * 5"
  kubecost_api_endpoint                            = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
}

module "us-east-2-111111111111-cluster2" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-111111111111-cluster2
  }

  cluster_arn                          = "arn:aws:eks:us-east-2:111111111111:cluster/cluster2"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  invoke_helm                          = false
}

#                                  #
# Clusters in Account 222222222222 #
#                                  #

# Clusters in Region us-east-1 #

module "us-east-1-222222222222-cluster1" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-222222222222-cluster1
    helm         = helm.us-east-1-222222222222-cluster1
  }

  cluster_arn                          = "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
  k8s_config_path                      = "~/configs/k8s/config"
}

module "us-east-1-222222222222-cluster2" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-222222222222-cluster2
    helm         = helm.us-east-1-222222222222-cluster2
  }

  cluster_arn                          = "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
}

# Clusters in Region us-east-2 #

module "us-east-2-222222222222-cluster1" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-222222222222-cluster1
    helm         = helm.us-east-2-222222222222-cluster1
  }

  cluster_arn                          = "arn:aws:eks:us-east-2:222222222222:cluster/cluster1"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
  invoke_helm                          = false
}

module "us-east-2-222222222222-cluster2" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-222222222222-cluster2
    helm         = helm.us-east-2-222222222222-cluster2
  }

  cluster_arn                          = "arn:aws:eks:us-east-2:222222222222:cluster/cluster2"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  namespace                            = "kubecost-s3-exporter-2"
  create_namespace                     = false
  service_account                      = "kubecost-s3-exporter-2"
  create_service_account               = false
}

####################################
# Section 3 - Quicksight Resources #
####################################

module "quicksight" {
  source = "../modules/quicksight"

  providers = {
    aws = aws.quicksight
  }

  aws_glue_database_name = module.pipeline.aws_glue_database_name
  aws_glue_view_name     = module.pipeline.aws_glue_view_name

  # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
  # Otherwise, remove the below field
  athena_workgroup_configuration = {
    query_results_location_bucket_name = "query-result-bucket"
  }

  qs_common_users = [
    {
      username = "Admin"
    },
    {
      username = "Admin2"
    }
  ]

  qs_data_source_settings = {
    users = [
      {
        username    = "Admin"
        permissions = "Viewer"
      },
      {
        username    = "Admin3"
        permissions = "Viewer"
      },
      {
        username = "Admin4"
      }
    ]
  }

  qs_data_set_settings = {
    timezone = "Asia/Jerusalem"
    users = [
      {
        username = "Admin4/udid-Isengard"
      },
      {
        username = "Admin/udid-Isengard"
      },
      {
        username    = "Admin3/udid-Isengard"
        permissions = "Viewer"
      }
    ]
  }
}