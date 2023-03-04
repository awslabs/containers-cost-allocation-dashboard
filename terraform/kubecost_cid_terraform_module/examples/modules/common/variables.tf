# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "bucket_arn" {
  type        = string
  default     = "arn:aws:s3:::kubecost-data-collection-bucket"
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
}

variable "irsa_aws_profile" {
  type        = string
  default     = "s3_bucket_account_aws_profile"
  description = "The AWS profile to use for configuration and credentials to create the IRSA in the S3 bucket's account"
}

variable "clusters_labels" {

  type = list(object({
    cluster_arn = string
    labels      = optional(list(string))
  }))

  default = [
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      "labels" : ["app", "chart"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
      "labels" : ["app", "chart"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-2:111111111111:cluster/cluster1"
      "labels" : ["app", "chart", "env"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
      "labels" : ["app", "chart", "owner", "environment"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
      "labels" : ["app", "chart", "owner"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-2:222222222222:cluster/cluster2"
      "labels" : ["app", "chart", "owner"]
    }
  ]

  description = "A map of clusters and their K8s labels that you wish to include in the dataset"
}

variable "aws_shared_config_files" {
  type        = list(string)
  default     = ["~/.aws/config"]
  description = "Paths to the AWS shared config files"
}

variable "aws_shared_credentials_files" {
  type        = list(string)
  default     = ["~/.aws/credentials"]
  description = "Paths to the AWS shared credentials files"
}

variable "granularity" {
  type        = string
  default     = "hourly"
  description = "The time granularity of the data that is returned from the Kubecost Allocation API"
}