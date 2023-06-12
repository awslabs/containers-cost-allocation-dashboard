# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source = "../modules/common"
}

# Example provider for the pipeline
provider "aws" {

  # This is an example, to help you get started

  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "pipeline_profile"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

# Example providers for cluster with Helm invocation
provider "aws" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster1"

  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile1"
  default_tags {
    tags = module.common.aws_common_tags
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

# Example providers for cluster without Helm invocation
provider "aws" {

  # This is an example, to help you get started

  alias = "us-east-1-111111111111-cluster2"

  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile1"
  default_tags {
    tags = module.common.aws_common_tags
  }
}