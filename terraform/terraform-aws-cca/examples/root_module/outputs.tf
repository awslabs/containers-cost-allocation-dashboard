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
output "us-east-1-111111111111-cluster1" {
  value       = module.us-east-1-111111111111-cluster1
  description = "The outputs for 'us-east-1-111111111111-cluster1'"
}

output "us-east-1-111111111111-cluster2" {
  value       = module.us-east-1-111111111111-cluster2
  description = "The outputs for 'us-east-1-111111111111-cluster2'"
}

output "us-east-2-111111111111-cluster1" {
  value       = module.us-east-2-111111111111-cluster1
  description = "The outputs for 'us-east-2-111111111111-cluster1'"
}

output "us-east-2-111111111111-cluster2" {
  value       = module.us-east-2-111111111111-cluster2
  description = "The outputs for 'us-east-2-111111111111-cluster2'"
}

output "us-east-1-222222222222-cluster1" {
  value       = module.us-east-1-222222222222-cluster1
  description = "The outputs for 'us-east-1-222222222222-cluster1'"
}

output "us-east-1-222222222222-cluster2" {
  value       = module.us-east-1-222222222222-cluster2
  description = "The outputs for 'us-east-1-222222222222-cluster2'"
}

output "us-east-2-222222222222-cluster1" {
  value       = module.us-east-2-222222222222-cluster1
  description = "The outputs for 'us-east-2-222222222222-cluster1'"
}

output "us-east-2-222222222222-cluster2" {
  value       = module.us-east-2-222222222222-cluster2
  description = "The outputs for 'us-east-2-222222222222-cluster2'"
}