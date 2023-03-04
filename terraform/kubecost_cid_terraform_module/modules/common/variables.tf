# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "bucket_arn" {
  type        = string
  default     = ""
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
}

variable "irsa_aws_profile" {
  type        = string
  default     = ""
  description = "The AWS profile to use for configuration and credentials to create the IRSA in the S3 bucket's account"
}

variable "clusters_labels" {

  type = list(object({
    cluster_arn = string
    labels      = optional(list(string))
  }))

  default = []

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