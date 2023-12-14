# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

output "static_columns" {
  description = "A list of the schema's static columns, mapped to their AWS Glue Table types and QuickSight Dataset types"
  value       = local.static_columns
}

output "partition_keys" {
  description = "A list of the schema's partition keys, mapped to their AWS Glue Table types and QuickSight Dataset types"
  value       = local.partition_keys
}