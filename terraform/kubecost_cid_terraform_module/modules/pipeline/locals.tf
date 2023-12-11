# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

locals {

  athena_view_sql = <<-EOF
    SELECT
      *
    FROM
      "${aws_glue_catalog_database.kubecost_glue_db.name}"."${aws_glue_catalog_table.kubecost_glue_table.name}"
    WHERE
      (
        (current_date - INTERVAL '${var.athena_view_data_retention_months}' MONTH) <= "window.start"
      )
    EOF

  static_columns         = [for column in module.common.static_columns : { name = column.name, type = column.persto_type }]
  labels_columns         = [for column in module.common.k8s_labels : { name = "properties.labels.${column}", type = "varchar" }]
  annotations_columns    = [for column in module.common.k8s_annotations : { name = "properties.annotations.${column}", type = "varchar" }]
  partition_keys_columns = [for column in module.common.partition_keys : { name = column.name, type = column.persto_type }]

  presto_view = jsonencode({
    originalSql = local.athena_view_sql,
    catalog     = "awsdatacatalog",
    schema      = var.glue_database_name,
    columns     = concat(local.static_columns, local.labels_columns, local.annotations_columns, local.partition_keys_columns)
  })

}