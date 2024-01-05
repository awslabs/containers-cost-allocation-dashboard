# This is the main entry point file where the calling modules are defined
# Follow the sections and the comments inside them, which provide instructions

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

################################
# Section 1 - Common Variables #
################################

# Calling module for the common module, to provide common variables values
# These variables are then used in other modules
module "common_variables" {
  source = "./modules/common_variables"

  bucket_arn      = "" # Add S3 bucket ARN here, of the bucket that will be used to store the data collected from Kubecost
  k8s_labels      = [] # Optionally, add K8s labels you'd like to be present in the dataset
  k8s_annotations = [] # Optionally, add K8s annotations you'd like to be present in the dataset
  aws_common_tags = {} # Optionally, add AWS common tags you'd like to be created on all resources
}

######################################
# Section 2 - AWS Pipeline Resources #
######################################

# Calling module for the pipeline module, to create the AWS pipeline resources
module "pipeline" {
  source = "./modules/pipeline"

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module, do not remove or change

  bucket_arn      = module.common_variables.bucket_arn
  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

  #                           #
  # Pipeline Module Variables #
  #                           #

  # Provide optional pipeline module variables values here, if needed

}

#########################################################
# Section 3 - Data Collection Pod Deployment using Helm #
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

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = module.common_variables.bucket_arn
  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

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

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module
  # Always include when creating new calling module, and do not remove or change

  bucket_arn      = module.common_variables.bucket_arn
  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = "" # Add the EKS cluster ARN here
  kubecost_s3_exporter_container_image = "" # Add the Kubecost S3 Exporter container image here (example: 111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0)
  invoke_helm                          = false
}

####################################
# Section 4 - Quicksight Resources #
####################################

# Calling module for the quicksight module, to create the QuickSight resources
module "quicksight" {
  source = "./modules/quicksight"

  providers = {
    aws          = aws.quicksight
    aws.identity = aws.quicksight-identity
  }

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module, do not remove or change

  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

  #                           #
  # Pipeline Module Variables #
  #                           #

  # References to variables outputs from the pipeline module, do not remove or change

  glue_database_name = module.pipeline.glue_database_name
  glue_view_name     = module.pipeline.glue_view_name

  #                             #
  # QuickSight Module Variables #
  #                             #

  # Provide quicksight module variables values here

  # This configuration block is used to define Athena workgroup
  # There are 2 options to use it:
  #
  # 1. Have Terraform create the Athena workgroup for you (the first uncommented block)
  # 2. Use an existing Athena workgroup (the second commented block)

  # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
  # It must be different from the S3 bucket used to store the Kubecost data
  # If you decided to use var.athena_workgroup_configuration.create as "false", remove the below field
  # Then, add the "name" field and specify and existing Athena workgroup

  # Block for having Terraform create Athena workgroup
  # You can optionally add the "name" field to change the default name that will used ("kubecost")
  athena_workgroup_configuration = {
    query_results_location_bucket_name = "" # Add an S3 bucket name for Athena Workgroup Query Results Location. It must be different from the S3 bucket used to store the Kubecost data
  }

  # Block for using an existing Athena workgroup
  # If you want to use it, comment the first block above, and uncomment the block below, then give the inputs
  # You can optionally add the "name" field to change the default name that will used ("kubecost")
#  athena_workgroup_configuration = {
#    create                             = false
#    name                               = "" # Add a name of an existing Athena Workgroup. Make sure it has Query Results Location set to an existing S3 bucket w hich is different from the S3 bucket used to store the Kubecost data
#    query_results_location_bucket_name = "" # Add an S3 bucket name for Athena Workgroup Query Results Location. It must be different from the S3 bucket used to store the Kubecost data
#  }

}