# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "bucket_arn" {
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
  value       = var.bucket_arn
}

output "aws_glue_database_name" {
  description = "The AWS Glue Database name"
  value       = var.aws_glue_database_name
}

output "aws_glue_table_name" {
  description = "The AWS Glue Table name"
  value       = var.aws_glue_table_name
}

output "aws_shared_config_files" {
  description = "Paths to the AWS shared config files"
  value       = var.aws_shared_config_files
}

output "aws_shared_credentials_files" {
  description = "Paths to the AWS shared credentials files"
  value       = var.aws_shared_credentials_files
}

output "k8s_labels" {
  description = "K8s labels common across all clusters, that you wish to include in the dataset"
  value       = var.k8s_labels
}

output "k8s_annotations" {
  description = "K8s annotations common across all clusters, that you wish to include in the dataset"
  value       = var.k8s_annotations
}

output "aws_common_tags" {
  description = "Common AWS tags to be used on all AWS resources created by Terraform"
  value       = var.aws_common_tags
}

output "static_columns" {
  description = "A list of the schema's static columns, mapped to their AWS Glue Table types and QuickSight Dataset types"
  value       = local.static_columns
}

output "partition_keys" {
  description = "A list of the schema's partition keys, mapped to their AWS Glue Table types and QuickSight Dataset types"
  value       = local.partition_keys
}