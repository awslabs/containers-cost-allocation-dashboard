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

  # References to variables outputs from the common module, do not remove

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

# Calling modules for the kubecost_s3_exporter module, to create IRSA and deploy the K8s resources

# Example calling module for cluster with Helm invocation
module "cluster1" {

  # This is an example, to help you get started

  source = "./modules/kubecost_s3_exporter"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster1
    helm         = helm.us-east-1-111111111111-cluster1
  }

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module
  # Always include when creating new calling module, and do not remove

  bucket_arn      = module.common_variables.bucket_arn
  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = ""
  kubecost_s3_exporter_container_image = ""
}

# Example calling module for cluster without Helm invocation
module "cluster2" {

  # This is an example, to help you get started

  source = "./modules/kubecost_s3_exporter"

  providers = {
    aws.pipeline = aws
    aws.eks      = aws.us-east-1-111111111111-cluster2
  }

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module
  # Always include when creating new calling module, and do not remove

  bucket_arn      = module.common_variables.bucket_arn
  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

  #                                       #
  # Kubecost S3 Exporter Module Variables #
  #                                       #

  # Provide kubecost_s3_exporter module variables values here

  cluster_arn                          = ""
  kubecost_s3_exporter_container_image = ""
  invoke_helm                          = false
}

####################################
# Section 4 - Quicksight Resources #
####################################

# Calling module for the quicksight module, to create the QuickSight resources
module "quicksight" {
  source = "./modules/quicksight"

  providers = {
    aws = aws.quicksight
  }

  #                         #
  # Common Module Variables #
  #                         #

  # References to variables outputs from the common module, do not remove

  k8s_labels      = module.common_variables.k8s_labels
  k8s_annotations = module.common_variables.k8s_annotations
  aws_common_tags = module.common_variables.aws_common_tags

  #                           #
  # Pipeline Module Variables #
  #                           #

  # References to variables outputs from the pipeline module, do not remove

  glue_database_name = module.pipeline.glue_database_name
  glue_view_name     = module.pipeline.glue_view_name

  #                             #
  # QuickSight Module Variables #
  #                             #

  # Provide quicksight module variables values here

  # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
  # Otherwise, remove the below field
  athena_workgroup_configuration = {
    query_results_location_bucket_name = ""
  }
}