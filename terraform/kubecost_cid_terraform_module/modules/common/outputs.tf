# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "bucket_arn" {
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
  value       = var.bucket_arn
}

output "clusters_metadata" {
  description = "A list of clusters and their additional metadata (K8s labels, annotations) that you wish to include in the dataset"
  value       = var.clusters_metadata
}

output "athena_workgroup_configuration" {
  description = "The configuration the Athena Workgroup. Used either to create a new Athena Workgroup, or reference configuration of an existing Athena Workgroup"
  value       = var.athena_workgroup_configuration
}

output "kubecost_ca_certificates_list" {
  description = "A list root CA certificates paths and their configuration for AWS Secrets Manager. Used for TLS communication with Kubecost. This is a consolidated list of all root CA certificates that are needed for all Kubecost endpoints"
  value       = var.kubecost_ca_certificates_list
}

output "aws_shared_config_files" {
  description = "Paths to the AWS shared config files"
  value       = var.aws_shared_config_files
}

output "aws_shared_credentials_files" {
  description = "Paths to the AWS shared credentials files"
  value       = var.aws_shared_credentials_files
}

output "aws_common_tags" {
  description = "Common AWS tags to be used on all AWS resources created by Terraform"
  value       = var.aws_common_tags
}