terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.26.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
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
  source = "./modules/pipeline"

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables, do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                           #
  # Pipeline Module Variables #
  #                           #

  # Provide pipeline module variables values here


}

#########################################################
# Section 2 - Data Collection Pod Deployment using Helm #
#########################################################

#                                  #
# Clusters in Account 111111111111 #
#                                  #

# Clusters in Region us-east-1 #

module "us-east-1-111111111111-cluster1" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster1
    helm         = helm.us-east-1-111111111111-cluster1
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

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
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster2
    helm         = helm.us-east-1-111111111111-cluster2
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  namespace                            = "kubecost-s3-exporter-2"
  service_account                      = "kubecost-s3-exporter-2"
  kubecost_allocation_api_paginate     = "Yes"
}

# Clusters in Region us-east-2 #

module "us-east-2-111111111111-cluster1" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-111111111111-cluster1
    helm         = helm.us-east-2-111111111111-cluster1
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                                      = "arn:aws:eks:us-east-2:111111111111:cluster/cluster1"
  kubecost_s3_exporter_container_image             = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_s3_exporter_container_image_pull_policy = "IfNotPresent"
  kubecost_s3_exporter_pod_schedule                = "0 0 * * 5"
  kubecost_api_endpoint                            = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
}

module "us-east-2-111111111111-cluster2" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-111111111111-cluster2
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = "arn:aws:eks:us-east-2:111111111111:cluster/cluster2"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  invoke_helm                          = false
}

#                                  #
# Clusters in Account 222222222222 #
#                                  #

# Clusters in Region us-east-1 #

module "us-east-1-222222222222-cluster1" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-222222222222-cluster1
    helm         = helm.us-east-1-222222222222-cluster1
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
  k8s_config_path                      = "~/configs/k8s/config"
}

module "us-east-1-222222222222-cluster2" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-222222222222-cluster2
    helm         = helm.us-east-1-222222222222-cluster2
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
}

# Clusters in Region us-east-2 #

module "us-east-2-222222222222-cluster1" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-222222222222-cluster1
    helm         = helm.us-east-2-222222222222-cluster1
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = "arn:aws:eks:us-east-2:222222222222:cluster/cluster1"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
  invoke_helm                          = false
}

module "us-east-2-222222222222-cluster2" {
  source = "./modules/kubecost_s3_exporetr"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-2-222222222222-cluster2
    helm         = helm.us-east-2-222222222222-cluster2
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

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
  source = "./modules/quicksight"

  providers = {
    aws          = aws.quicksight
    aws.identity = aws.quicksight-identity
  }

  #                              #
  # Root Module Common Variables #
  #                              #

  # References to root module common variables, do not remove or change

  bucket_arn      = var.bucket_arn
  k8s_labels      = var.k8s_labels
  k8s_annotations = var.k8s_annotations
  aws_common_tags = var.aws_common_tags

  #                           #
  # Pipeline Module Variables #
  #                           #

  # References to variables outputs from the pipeline module, do not remove

  aws_glue_database_name = module.pipeline.aws_glue_database_name
  aws_glue_view_name     = module.pipeline.aws_glue_view_name

  #                             #
  # QuickSight Module Variables #
  #                             #

  # Provide quicksight module variables values here

  # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
  # Otherwise, remove the below field
  athena_workgroup_configuration = {
    query_results_location_bucket_name = "query-result-bucket"
  }

  qs_common_users = [
    {
      username = "user1"
    },
    {
      username = "user2"
    }
  ]

  qs_data_source_settings = {
    users = [
      {
        username    = "user1"
        permissions = "Viewer"
      },
      {
        username    = "user3"
        permissions = "Viewer"
      },
      {
        username = "user4"
      }
    ]
  }

  qs_data_set_settings = {
    timezone = "Asia/Jerusalem"
    users = [
      {
        username = "user4"
      },
      {
        username = "user1"
      },
      {
        username    = "user3"
        permissions = "Viewer"
      }
    ]
  }
}