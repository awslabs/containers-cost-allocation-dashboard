# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

# Output for showing the distinct labels from all clusters, collected from the "clusters_metadata" common input
output "labels" {
  value       = join(", ", module.common.distinct_labels)
  description = "A list of the distinct labels of all clusters, that'll be added to the dataset"
}

# Output for showing the distinct annotations from all clusters, collected from the "clusters_metadata" common input
output "annotations" {
  value       = join(", ", module.common.distinct_annotations)
  description = "A list of the distinct annotations of all clusters, that'll be added to the dataset"
}

# Clusters outputs
output "cluster1" {
  value       = module.cluster1
  description = "The outputs for 'cluster1'"
}