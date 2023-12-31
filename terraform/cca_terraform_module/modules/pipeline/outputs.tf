output "glue_database_name" {
  description = "The AWS Glue Database name"
  value       = aws_glue_catalog_database.kubecost_glue_db.name
}

output "glue_view_name" {
  description = "The AWS Glue Table name for the Athena view"
  value       = aws_glue_catalog_table.kubecost_glue_view.name
}

output "kubecost_ca_cert_secret" {
  description = "All AWS Secrets Manager Secrets"
  value       = aws_secretsmanager_secret.kubecost_ca_cert_secret
}