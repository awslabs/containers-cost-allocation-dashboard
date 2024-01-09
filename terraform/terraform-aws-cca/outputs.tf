# Output for showing the distinct labels from all clusters, collected from the "k8s_labels" common input
output "labels" {
  value       = length(var.k8s_labels) > 0 ? join(", ", distinct(var.k8s_labels)) : null
  description = "A list of the distinct labels of all clusters, that'll be added to the dataset"
}

# Output for showing the distinct annotations from all clusters, collected from the "k8s_annotations" common input
output "annotations" {
  value       = length(var.k8s_annotations) > 0 ? join(", ", distinct(var.k8s_annotations)) : null
  description = "A list of the distinct annotations of all clusters, that'll be added to the dataset"
}

# Clusters outputs
#output "cluster1" {
#
#  # This is an example, to help you get started
#
#  value       = module.cluster1
#  description = "The outputs for 'cluster1'"
#}
