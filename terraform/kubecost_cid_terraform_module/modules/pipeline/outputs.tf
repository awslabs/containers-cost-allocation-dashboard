# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "labels" {
  value       = local.labels_for_output
  description = "List of the distinct labels from all clusters"
}