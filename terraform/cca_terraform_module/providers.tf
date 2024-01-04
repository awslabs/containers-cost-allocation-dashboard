#####################################
# Section 1 - Pipeline AWS Provider #
#####################################

# Example provider for the pipeline
provider "aws" {

  # This is an example, to help you get started

  region                   = "us-east-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "pipeline_profile"
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

###########################################################
# Section 2 - Kubecost S3 Exporter AWS and Helm Providers #
###########################################################

#                                                    #
# Example providers for cluster with Helm invocation #
#                                                    #

provider "aws" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster1"

  region                   = "us-east-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "profile1"
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

provider "helm" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster1"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
    config_path    = "~/.kube/config"
  }
}

#                                                       #
# Example provider for cluster without Helm invocation  #
#                                                       #

provider "aws" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster2"

  region                   = "us-east-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "profile1"
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

#######################################
# Section 3 - Quicksight AWS Provider #
#######################################

# Example provider for QuickSight
provider "aws" {

  # This is an example, to help you get started

  alias = "quicksight"

  region                   = "us-east-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "quicksight_profile"
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}

provider "aws" {

  # This is an example, to help you get started

  alias = "quicksight-identity"

  region                   = "us-east-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "quicksight_profile"
  default_tags {
    tags = module.common_variables.aws_common_tags
  }
}