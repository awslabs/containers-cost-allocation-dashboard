# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "irsa_child_iam_role_arn" {
  value       = aws_iam_role.kubecost_s3_exporter_irsa_child_role.arn
  description = "The ARN of the IAM Role that was created as part of IRSA"
}

output "irsa_parent_iam_role_arn" {
  value       = aws_iam_role.kubecost_s3_exporter_irsa_parent_role.arn
  description = "The ARN of the parent IAM Role that was created as part of IRSA role chaining"
}