# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

provider "aws" {
  region = local.region
}

provider "helm" {
  kubernetes {
    config_path = local.k8s_config_path
  }
}