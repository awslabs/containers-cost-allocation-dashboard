# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "labels" {
  description = "List of the distinct labels from all clusters"
  value       = length(local.labels_for_output) > 0 ? local.labels_for_output : null
}

output "annotations" {
  description = "List of the distinct annotations from all clusters"
  value       = length(local.annotations_for_output) > 0 ? local.annotations_for_output : null
}

output "kubecost_ca_cert_secret" {
  description = "All AWS Secrets Manager Secrets"
  value       = aws_secretsmanager_secret.kubecost_ca_cert_secret
}

output "custom_athena_workgroup" {
  description = "The configuration the Athena Workgroup. Used either to create a new Athena Workgroup, or reference configuration of an existing Athena Workgroup"
  value       = aws_athena_workgroup.kubecost_athena_workgroup
}