output "static_columns" {
  description = "A list of the schema's static columns, mapped to their QuickSight Dataset types, hive types and presto types"
  value       = local.static_columns
}

output "partition_keys" {
  description = "A list of the schema's partition keys, mapped to their QuickSight Dataset types, hive types and presto types"
  value       = local.partition_keys
}
