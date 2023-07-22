# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "kubecost_ca_cert_secret" {
  description = "All AWS Secrets Manager Secrets"
  value       = aws_secretsmanager_secret.kubecost_ca_cert_secret
}

output "custom_athena_workgroup" {
  description = "The configuration the Athena Workgroup. Used either to create a new Athena Workgroup, or reference configuration of an existing Athena Workgroup"
  value       = aws_athena_workgroup.kubecost_athena_workgroup
}

output "aws_glue_table" {
  description = "The AWS Glue Table used to store the Kubecost data"
  value       = aws_glue_catalog_table.kubecost_glue_table
}