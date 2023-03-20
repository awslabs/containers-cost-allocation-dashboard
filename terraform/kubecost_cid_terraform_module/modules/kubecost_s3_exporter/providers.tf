# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

provider "aws" {
  region                   = var.aws_region
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = var.aws_profile
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "aws" {
  alias                    = "irsa_parent_role"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = module.common.irsa_parent_role_aws_profile
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "helm" {
  kubernetes {
    config_context = var.cluster_context
    config_path    = var.k8s_config_path
  }
}