# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

# Output to show the distinct labels from all clusters, collected from the "clusters_labels" common input
output "labels" {
  value = module.pipeline.labels
  description = "A list of the distinct lab of all clusters, that'll be added to the dataset"
}

# Outputs to show the IRSA IAM Role ARN that was created for each cluster
output "cluster1-us-east-1-111111111111_irsa_iam_role_arn" {
  value = module.cluster1-us-east-1-111111111111.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster2-us-east-1-111111111111_irsa_iam_role_arn" {
  value = module.cluster2-us-east-1-111111111111.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster1-us-east-2-111111111111_irsa_iam_role_arn" {
  value = module.cluster1-us-east-2-111111111111.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster2-us-east-2-111111111111_irsa_iam_role_arn" {
  value = module.cluster2-us-east-2-111111111111.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster1-us-east-1-222222222222_irsa_iam_role_arn" {
  value = module.cluster1-us-east-1-222222222222.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster2-us-east-1-222222222222_irsa_iam_role_arn" {
  value = module.cluster2-us-east-1-222222222222.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster1-us-east-2-222222222222_irsa_iam_role_arn" {
  value = module.cluster1-us-east-2-222222222222.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}

output "cluster2-us-east-2-222222222222_irsa_iam_role_arn" {
  value = module.cluster2-us-east-2-222222222222.irsa_iam_role_arn
  description = "The IRSA IAM Role ARN for this cluster"
}