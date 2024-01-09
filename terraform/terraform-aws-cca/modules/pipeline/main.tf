module "common_locals" {
  source = "../common_locals"
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.63.0"
    }
  }
}

data "aws_partition" "pipeline" {}
data "aws_region" "pipeline" {}
data "aws_caller_identity" "pipeline" {}

resource "aws_iam_policy" "kubecost_glue_crawler" {
  name = "kubecost_glue_crawler_policy"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "glue:GetTable",
            "glue:GetDatabase",
            "glue:GetPartition",
            "glue:CreatePartition",
            "glue:UpdatePartition",
            "glue:BatchGetPartition",
            "glue:BatchCreatePartition",
            "glue:BatchUpdatePartition"
          ]
          Effect = "Allow"
          Resource = [
            "arn:${data.aws_partition.pipeline.partition}:glue:${data.aws_region.pipeline.name}:${data.aws_caller_identity.pipeline.account_id}:catalog",
            aws_glue_catalog_database.kubecost.arn,
            aws_glue_catalog_table.kubecost.arn,
            "${replace(aws_glue_catalog_table.kubecost.arn, aws_glue_catalog_table.kubecost.name, replace(local.bucket_name, "-", "_"))}*"
          ]
          Sid = "AllowGlueKubecostTable"
        },
        {
          Action = [
            "s3:GetObject",
            "s3:ListBucket",
          ]
          Effect = "Allow"
          Resource = [
            "${var.bucket_arn}/*",
            var.bucket_arn,
          ]
          Sid = "AllowS3KubecostBucket"
        },
        {
          Action   = "logs:CreateLogGroup"
          Effect   = "Allow"
          Resource = "arn:${data.aws_partition.pipeline.partition}:logs:${data.aws_region.pipeline.name}:${data.aws_caller_identity.pipeline.account_id}:*"
          Sid      = "AllowCloudWatchLogsCreateLogGroupForGlueCrawlers"
        },
        {
          Action   = "logs:CreateLogStream"
          Effect   = "Allow"
          Resource = "arn:${data.aws_partition.pipeline.partition}:logs:${data.aws_region.pipeline.name}:${data.aws_caller_identity.pipeline.account_id}:log-group:/aws-glue/crawlers:*"
          Sid      = "AllowCloudWatchLogsCreateLogStreamForKubecostCrawler"
        },
        {
          Action   = "logs:PutLogEvents"
          Effect   = "Allow"
          Resource = "arn:${data.aws_partition.pipeline.partition}:logs:${data.aws_region.pipeline.name}:${data.aws_caller_identity.pipeline.account_id}:log-group:/aws-glue/crawlers:log-stream:kubecost_crawler"
          Sid      = "AllowCloudWatchLogsPutLogs"
        }
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role" "kubecost_glue_crawler" {
  name = "kubecost_glue_crawler_role"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "glue.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  managed_policy_arns = [aws_iam_policy.kubecost_glue_crawler.arn]
}

resource "aws_glue_catalog_database" "kubecost" {
  name = var.glue_database_name
}

resource "aws_glue_catalog_table" "kubecost" {
  name          = var.glue_table_name
  database_name = aws_glue_catalog_database.kubecost.name
  parameters = {
    "classification" = "parquet"
  }

  table_type = "EXTERNAL_TABLE"

  dynamic "partition_keys" {
    for_each = [for partition_key in module.common_locals.partition_keys : partition_key]
    content {
      name = partition_keys.value.name
      type = partition_keys.value.hive_type
    }
  }

  storage_descriptor {
    location      = "s3://${local.bucket_name}/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    parameters = {
      "classification" = "parquet"
    }

    ser_de_info {
      name                  = "kubecost_table_parquet_serde"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
    }

    dynamic "columns" {
      for_each = [for static_column in module.common_locals.static_columns : static_column]
      content {
        name = columns.value.name
        type = columns.value.hive_type
      }
    }
    dynamic "columns" {
      for_each = [for k8s_label in distinct(var.k8s_labels) : k8s_label]
      content {
        name = "properties.labels.${columns.value}"
        type = "string"
      }
    }
    dynamic "columns" {
      for_each = [for k8s_annotation in distinct(var.k8s_annotations) : k8s_annotation]
      content {
        name = "properties.annotations.${columns.value}"
        type = "string"
      }
    }
  }
}

resource "aws_glue_catalog_table" "kubecost_view" {
  name          = var.glue_view_name
  database_name = aws_glue_catalog_database.kubecost.name
  parameters = {
    presto_view = "true"
    comment     = "Presto View"
  }

  table_type         = "VIRTUAL_VIEW"
  view_expanded_text = "/* Presto View */"
  view_original_text = "/* Presto View: ${base64encode(local.presto_view)} */"

  storage_descriptor {
    dynamic "columns" {
      for_each = [for static_column in module.common_locals.static_columns : static_column]
      content {
        name = columns.value.name
        type = columns.value.hive_type
      }
    }
    dynamic "columns" {
      for_each = [for k8s_label in distinct(var.k8s_labels) : k8s_label]
      content {
        name = "properties.labels.${columns.value}"
        type = "string"
      }
    }
    dynamic "columns" {
      for_each = [for k8s_annotation in distinct(var.k8s_annotations) : k8s_annotation]
      content {
        name = "properties.annotations.${columns.value}"
        type = "string"
      }
    }
    dynamic "columns" {
      for_each = [for partition_key in module.common_locals.partition_keys : partition_key]
      content {
        name = columns.value.name
        type = columns.value.hive_type
      }
    }
  }
}

resource "aws_glue_crawler" "kubecost" {
  name          = var.glue_crawler_name
  database_name = aws_glue_catalog_database.kubecost.name
  schedule      = "cron(${var.glue_crawler_schedule})"
  role          = aws_iam_role.kubecost_glue_crawler.name

  catalog_target {
    database_name = aws_glue_catalog_database.kubecost.name
    tables = [
      aws_glue_catalog_table.kubecost.name
    ]
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }

  configuration = jsonencode(
    {
      CrawlerOutput = {
        Partitions = {
          AddOrUpdateBehavior = "InheritFromTable"
        }
      }
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas"
      }
      Version = 1
    }
  )
}

# The next 3 resources are conditionally created
# If the "kubecost_ca_certificates_list" variable isn't empty, a secret containing the CA certificate will be created
# Else, it won't be created
resource "aws_secretsmanager_secret" "kubecost_ca_cert" {
  count = length(var.kubecost_ca_certificates_list) > 0 ? length(var.kubecost_ca_certificates_list) : 0

  name                    = var.kubecost_ca_certificates_list[count.index].cert_secret_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "kubecost_ca_cert" {
  count = length(var.kubecost_ca_certificates_list) > 0 ? length(var.kubecost_ca_certificates_list) : 0

  secret_id     = aws_secretsmanager_secret.kubecost_ca_cert[count.index].id
  secret_string = file(var.kubecost_ca_certificates_list[count.index].cert_path)
}

resource "aws_secretsmanager_secret_policy" "kubecost_ca_cert" {
  count = length(var.kubecost_ca_certificates_list) > 0 ? length(var.kubecost_ca_certificates_list) : 0

  secret_arn = aws_secretsmanager_secret.kubecost_ca_cert[count.index].arn
  policy = templatefile("${path.module}/secret_policy.tpl", {
    arn        = aws_secretsmanager_secret.kubecost_ca_cert[count.index].id
    principals = var.kubecost_ca_certificates_list[count.index].cert_secret_allowed_principals
  })
}
