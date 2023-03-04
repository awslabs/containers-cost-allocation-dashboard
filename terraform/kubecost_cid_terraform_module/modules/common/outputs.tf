# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "bucket_arn" {
  value       = var.bucket_arn
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
}

output "irsa_aws_profile" {
  value       = var.irsa_aws_profile
  description = "The AWS profile to use for configuration and credentials to create the IRSA in the S3 bucket's account"
}

output "clusters_labels" {
  value       = var.clusters_labels
  description = "A map of clusters and their K8s labels that you wish to include in the dataset"
}

output "aws_shared_config_files" {
  value       = var.aws_shared_config_files
  description = "Paths to the AWS shared config files"
}

output "aws_shared_credentials_files" {
  value       = var.aws_shared_credentials_files
  description = "Paths to the AWS shared credentials files"
}

output "granularity" {
  value       = var.granularity
  description = "The time granularity of the data that is returned from the Kubecost Allocation API"
}