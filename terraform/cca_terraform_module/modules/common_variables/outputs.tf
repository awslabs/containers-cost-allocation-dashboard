# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "bucket_arn" {
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
  value       = var.bucket_arn
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