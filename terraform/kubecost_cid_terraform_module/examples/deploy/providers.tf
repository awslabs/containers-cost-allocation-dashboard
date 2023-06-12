# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source = "../modules/common"
}


######################################
# Section 1 - AWS Resources Pipeline #
######################################

provider "aws" {
  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "pipeline_profile"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

#########################################################
# Section 2 - Data Collection Pod Deployment using Helm #
#########################################################

#                                  #
# Clusters in Account 111111111111 #
#                                  #

# Clusters in Region us-east-1 #

provider "aws" {
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
  alias = "us-east-1-111111111111-cluster1"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
    config_path    = "~/.kube/config"
  }
}

provider "aws" {
  alias = "us-east-1-111111111111-cluster2"

  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile1"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "helm" {
  alias = "us-east-1-111111111111-cluster2"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
    config_path    = "~/.kube/config"
  }
}

# Clusters in Region us-east-2 #

provider "aws" {
  alias = "us-east-2-111111111111-cluster1"

  region                   = "us-east-2"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile1"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "helm" {
  alias = "us-east-2-111111111111-cluster1"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
    config_path    = "~/.kube/config"
  }
}

provider "aws" {
  alias = "us-east-2-111111111111-cluster2"

  region                   = "us-east-2"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile1"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

#                                  #
# Clusters in Account 222222222222 #
#                                  #

# Clusters in Region us-east-1 #

provider "aws" {
  alias = "us-east-1-222222222222-cluster1"

  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile2"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "helm" {
  alias = "us-east-1-222222222222-cluster1"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
    config_path    = "~/.kube/config"
  }
}

provider "aws" {
  alias = "us-east-1-222222222222-cluster2"

  region                   = "us-east-1"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile2"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "helm" {
  alias = "us-east-1-222222222222-cluster2"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
    config_path    = "~/.kube/config"
  }
}

# Clusters in Region us-east-2 #

provider "aws" {
  alias = "us-east-2-222222222222-cluster1"

  region                   = "us-east-2"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile2"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "aws" {
  alias = "us-east-2-222222222222-cluster2"

  region                   = "us-east-2"
  shared_config_files      = module.common.aws_shared_config_files
  shared_credentials_files = module.common.aws_shared_credentials_files
  profile                  = "profile2"
  default_tags {
    tags = module.common.aws_common_tags
  }
}

provider "helm" {
  alias = "us-east-2-222222222222-cluster2"

  kubernetes {
    config_context = "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
    config_path    = "~/.kube/config"
  }
}