# This is the providers blocks file
# Follow the sections and the comments inside them, which provide instructions

#####################################
# Section 1 - Pipeline AWS Provider #
#####################################

# Provider for the pipeline module
provider "aws" {

  # This is an example, to help you get started

  region                   = "us-east-1"            # Change the region if necessary
  shared_config_files      = ["~/.aws/config"]      # Change the path to the shared config file, if necessary
  shared_credentials_files = ["~/.aws/credentials"] # Change the path to the shared credential file, if necessary
  profile                  = "pipeline_profile"     # Change to the profile that will be used for the account and region where the pipeline resources will be deployed
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

###########################################################
# Section 2 - Kubecost S3 Exporter AWS and Helm Providers #
###########################################################

# Providers for the kubecost_s3_exporter module.
# Used to deploy the K8s resources on clusters, and creates IRSA in cluster's accounts
# There are 2 deployment options:
#
# 1. Deploy the K8s resources by having Terraform invoke Helm
#    In this case, you have to define 2 providers per cluster - an AWS provider and a Helm provider
# 2. Deploy the K8s resources by having Terraform generate a Helm values.yaml, then you deploy it using Helm
#    In this case, you have to define 1 provider per cluster - an AWS provider

#                                                    #
# Example providers for cluster with Helm invocation #
#                                                    #

# Use these providers if you'd like Terraform to invoke Helm to deploy the K8s resources
# Duplicate the providers for each cluster on which you wish to deploy the Kubecost S3 Exporter

provider "aws" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster1"          # Change to an alias that uniquely identifies the cluster within all the AWS provider blocks

  region                   = "us-east-1"             # Change the region if necessary
  shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
  shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
  profile                  = "profile1"              # Change to the profile that identifies the account and region where the cluster is
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

provider "helm" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster1"                                 # Change to an alias that uniquely identifies the cluster within all the Helm provider blocks

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"  # Change to the context that identifies the cluster in the K8s config file (in many cases it's the cluster ARN)
    config_path    = "~/.kube/config"                                       # Change to the full path of the K8s config file
  }
}

#                                                       #
# Example provider for cluster without Helm invocation  #
#                                                       #

# Use this provider if you'd like Terraform to generate a Helm values.yaml, then you deploy it using Helm
# Duplicate the provider for each cluster on which you wish to deploy the Kubecost S3 Exporter
provider "aws" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster2"          # Change to an alias that uniquely identifies the cluster within all AWS Helm provider blocks

  region                   = "us-east-1"             # Change the region if necessary
  shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
  shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
  profile                  = "profile1"              # Change to the profile that identifies the account and region where the cluster is
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

#######################################
# Section 3 - Quicksight AWS Provider #
#######################################

#                          #
# Providers for QuickSight #
#                          #

# Providers for the QuickSight module.
# Used to deploy the QuickSight resources and to identify the QuickSight users
# It has 2 providers:
#
# 1. The first provider block is to identify the account and QuickSight region where the dashboard will be deployed
# 2. The second provider block is to identify the QuickSight identity region (where the QuickSight users are)
#    To identify the identity region:
#    a. Log in to QuickSight
#    b. On the top right, click the person button, and switch to the region where you intend to deploy the dashboard.
#       This is the same region as in the first provider
#    c. On the top right, click the person button again, and click "Manage QuickSight"
#    d. On the left pane, click "Security & permissions".
#       If you see the "Security & permissions" page, then the identity region is the same as the dashboard region.
#       If you see a message "Switch to `<region name>` to edit permissions or unsubscribe", then the region in the message is the identity region.
#       Use it in the `region` field on the second provider block

# Provider for QuickSight account and region where the dashboard will be deployed
provider "aws" {

  # This is an example, to help you get started

  alias = "quicksight"

  region                   = "us-east-1"             # Change the region if necessary. This is the region you select on the top right part of the QuickSight UI
  shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
  shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
  profile                  = "quicksight_profile"    # Change to the profile that will be used for the account and region where the QuickSight dashboard will be deployed
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

# Provider for QuickSight identity region
provider "aws" {

  # This is an example, to help you get started

  alias = "quicksight-identity"

  region                   = "us-east-1"             # Change the region if necessary. This is the region you identified in the steps above
  shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
  shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
  profile                  = "quicksight_profile"    # Change to the profile that will be used to identify the QuickSight identity region
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}