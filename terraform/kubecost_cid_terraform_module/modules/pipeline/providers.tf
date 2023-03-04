# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

provider "aws" {
  region                   = var.aws_region
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = var.aws_profile
}