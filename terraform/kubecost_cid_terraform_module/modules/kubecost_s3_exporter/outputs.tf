# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "irsa_iam_role_arn" {
  value       = aws_iam_role.kubecost_s3_exporter_service_account_role.arn
  description = "The ARN of the IAM Role that was created as part of IRSA"
}