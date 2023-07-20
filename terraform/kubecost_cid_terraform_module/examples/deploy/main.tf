# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.8.0"
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
  }
}

######################################
# Section 1 - AWS Resources Pipeline #
######################################

module "pipeline" {
  source = "../modules/pipeline"

  glue_crawler_schedule = "0 1 * * ? *"
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
  cluster_oidc_provider_arn            = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/1"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "https://kubecost-eks-cost-analyzer.kubecost-eks"
  connection_timeout                   = 5
  kubecost_allocation_api_read_timeout = 30
  kubecost_assets_api_read_timeout     = 10
  tls_verify                           = "no"
  kubecost_ca_certificate_secret_name  = "kubecost"
  kubecost_ephemeral_volume_size       = "100Mi"
  backfill_period_days                 = 5

  depends_on = [module.pipeline.kubecost_ca_cert_secret]
}

module "us-east-1-111111111111-cluster2" {
  source = "../modules/helm"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster2
    helm         = helm.us-east-1-111111111111-cluster2
  }

  cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
  cluster_oidc_provider_arn            = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/2"
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
  cluster_oidc_provider_arn                        = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/3"
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
  cluster_oidc_provider_arn            = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/4"
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
  cluster_oidc_provider_arn            = "arn:aws:iam::222222222222:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/5"
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
  cluster_oidc_provider_arn            = "arn:aws:iam::222222222222:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/6"
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
  cluster_oidc_provider_arn            = "arn:aws:iam::222222222222:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/7"
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
  cluster_oidc_provider_arn            = "arn:aws:iam::222222222222:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/8"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  namespace                            = "kubecost-s3-exporter-2"
  create_namespace                     = false
  service_account                      = "kubecost-s3-exporter-2"
  create_service_account               = false
}