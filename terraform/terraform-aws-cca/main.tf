# This is the main entry point file where the calling modules are defined
# Follow the sections and the comments inside them, which provide instructions

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
  }
}

######################################
# Section 1 - AWS Pipeline Resources #
######################################

# Calling module for the pipeline module, to create the AWS pipeline resources
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

  # Provide optional pipeline module variables values here, if needed

}

#########################################################
# Section 2 - Data Collection Pod Deployment using Helm #
#########################################################

# Calling modules for the kubecost_s3_exporter module.
# Deploys the K8s resources on clusters, and creates IRSA in cluster's accounts
# There are 2 deployment options:
#
# 1. Deploy the K8s resources by having Terraform invoke Helm
#    This option is shown in the "cluster1" calling module example
# 2. Deploy the K8s resources by having Terraform generate a Helm values.yaml, then you deploy it using Helm
#    This option is shown in the "cluster2" calling module example

# Example calling module for cluster with Helm invocation
# Use it if you'd like Terraform to invoke Helm to deploy the K8s resources
# Replace "cluster1" with a unique name to identify the cluster
# Duplicate the calling module for each cluster on which you wish to deploy the Kubecost S3 Exporter
module "cluster1" {

  # This is an example, to help you get started

  source = "./modules/kubecost_s3_exporter"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster1  # Replace with the AWS provider alias for the cluster
    helm         = helm.us-east-1-111111111111-cluster1 # Replace with the Helm provider alias for the cluster
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

  cluster_arn                          = "" # Add the EKS cluster ARN here
  kubecost_s3_exporter_container_image = "" # Add the Kubecost S3 Exporter container image here (example: 111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0)
}

# Example calling module for cluster without Helm invocation
# Use it if you'd like Terraform to generate a Helm values.yaml, then you deploy it using Helm
# Replace "cluster2" with a unique name to identify the cluster
# Duplicate the calling module for each cluster on which you wish to deploy the Kubecost S3 Exporter
module "cluster2" {

  # This is an example, to help you get started

  source = "./modules/kubecost_s3_exporter"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster2 # Replace with the AWS provider alias for the cluster
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

  cluster_arn                          = "" # Add the EKS cluster ARN here
  kubecost_s3_exporter_container_image = "" # Add the Kubecost S3 Exporter container image here (example: 111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0)
  invoke_helm                          = false
}
