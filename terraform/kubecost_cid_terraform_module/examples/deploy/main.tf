# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

######################################
# Section 1 - AWS Resources Pipeline #
######################################

module "pipeline" {
  source = "../modules/pipeline"

  aws_region            = "us-east-1"
  aws_profile           = "pipeline_profile"
  glue_crawler_schedule = "cron(0 1 * * ? *)"
}

#########################################################
# Section 2 - Data Collection Pod Deployment using Helm #
#########################################################

#                                  #
# Clusters in Account 111111111111 #
#                                  #

# Clusters in Region us-east-1 #

module "cluster1-us-east-1-111111111111" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
  cluster_context                      = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/1"
  aws_region                           = "us-east-1"
  aws_profile                          = "profile1"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
}

module "cluster2-us-east-1-111111111111" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
  cluster_context                      = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/2"
  aws_region                           = "us-east-1"
  aws_profile                          = "profile1"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  namespace                            = "kubecost-s3-exporter-2"
  service_account                      = "kubecost-s3-exporter-2"
}

# Clusters in Region us-east-2 #

module "cluster1-us-east-2-111111111111" {
  source = "../modules/helm"

  cluster_arn                                      = "arn:aws:eks:us-east-2:111111111111:cluster/cluster1"
  cluster_context                                  = "context_cluster1_us-east-2_111111111111"
  cluster_oidc_provider_arn                        = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/3"
  aws_region                                       = "us-east-2"
  aws_profile                                      = "profile1"
  kubecost_s3_exporter_container_image             = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_s3_exporter_container_image_pull_policy = "IfNotPresent"
  kubecost_s3_exporter_pod_schedule                = "0 0 * * 5"
  kubecost_api_endpoint                            = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
}

module "cluster2-us-east-2-111111111111" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-2:111111111111:cluster/cluster2"
  cluster_context                      = "context_cluster2_us-east-2_111111111111"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/4"
  aws_region                           = "us-east-2"
  aws_profile                          = "profile1"
  kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  invoke_helm                          = false
}

#                                  #
# Clusters in Account 222222222222 #
#                                  #

# Clusters in Region us-east-1 #

module "cluster1-us-east-1-222222222222" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
  cluster_context                      = "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/5"
  aws_region                           = "us-east-1"
  aws_profile                          = "profile2"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
  k8s_config_path                      = "~/configs/k8s/config"
}

module "cluster2-us-east-1-222222222222" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
  cluster_context                      = "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/6"
  aws_region                           = "us-east-1"
  aws_profile                          = "profile1"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
}

# Clusters in Region us-east-2 #

module "cluster1-us-east-2-222222222222" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-2:222222222222:cluster/cluster1"
  cluster_context                      = "context_cluster1_us-east-2_222222222222"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/7"
  aws_region                           = "us-east-2"
  aws_profile                          = "profile2"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  kubecost_api_endpoint                = "http://kubecost-eks-cost-analyzer.kubecost-eks:9090"
  invoke_helm                          = false
}

module "cluster2-us-east-2-222222222222" {
  source = "../modules/helm"

  cluster_arn                          = "arn:aws:eks:us-east-2:222222222222:cluster/cluster2"
  cluster_context                      = "context_cluster2_us-east-2_222222222222"
  cluster_oidc_provider_arn            = "arn:aws:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/8"
  aws_region                           = "us-east-2"
  aws_profile                          = "profile1"
  kubecost_s3_exporter_container_image = "222222222222.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
  namespace                            = "kubecost-s3-exporter-2"
  create_namespace                     = false
  service_account                      = "kubecost-s3-exporter-2"
  create_service_account               = false
}