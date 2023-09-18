# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source = "../common"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.63.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

resource "aws_iam_policy" "kubecost_glue_crawler_policy" {
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
            "${element(split("database/", aws_glue_catalog_database.kubecost_glue_db.arn), 0)}catalog",
            aws_glue_catalog_database.kubecost_glue_db.arn,
            aws_glue_catalog_table.kubecost_glue_table.arn,
            "${replace(aws_glue_catalog_table.kubecost_glue_table.arn, aws_glue_catalog_table.kubecost_glue_table.name, replace("${element(split(":::", module.common.bucket_arn), 1)}", "-", "_"))}*"
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
            "${module.common.bucket_arn}/*",
            module.common.bucket_arn,
          ]
          Sid = "AllowS3KubecostBucket"
        },
        {
          Action   = "logs:CreateLogGroup"
          Effect   = "Allow"
          Resource = "${replace(element(split("database/", aws_glue_catalog_database.kubecost_glue_db.arn), 0), ":glue:", ":logs:")}*"
          Sid      = "AllowCloudWatchLogsCreateLogGroupForGlueCrawlers"
        },
        {
          Action   = "logs:CreateLogStream"
          Effect   = "Allow"
          Resource = "${replace(element(split("database/", aws_glue_catalog_database.kubecost_glue_db.arn), 0), ":glue:", ":logs:")}log-group:/aws-glue/crawlers:*"
          Sid      = "AllowCloudWatchLogsCreateLogStreamForKubecostCrawler"
        },
        {
          Action   = "logs:PutLogEvents"
          Effect   = "Allow"
          Resource = "${replace(element(split("database/", aws_glue_catalog_database.kubecost_glue_db.arn), 0), ":glue:", ":logs:")}log-group:/aws-glue/crawlers:log-stream:kubecost_crawler"
          Sid      = "AllowCloudWatchLogsPutLogs"
        }
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role" "kubecost_glue_crawler_role" {
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
  managed_policy_arns = [
    aws_iam_policy.kubecost_glue_crawler_policy.arn,
  ]
}

resource "aws_glue_catalog_database" "kubecost_glue_db" {
  name = module.common.aws_glue_database_name
}

resource "aws_glue_catalog_table" "kubecost_glue_table" {
  name          = module.common.aws_glue_table_name
  database_name = aws_glue_catalog_database.kubecost_glue_db.name
  parameters = {
    "classification" = "parquet"
  }

  table_type = "EXTERNAL_TABLE"

  dynamic "partition_keys" {
    for_each = [for partition_key in module.common.partition_keys : partition_key]
    content {
      name = partition_keys.value.name
      type = partition_keys.value.glue_table_type
    }
  }

  storage_descriptor {
    location      = "s3://${element(split(":::", module.common.bucket_arn), 1)}/"
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
      for_each = [for static_column in module.common.static_columns : static_column]
      content {
        name = columns.value.name
        type = columns.value.glue_table_type
      }
    }
    dynamic "columns" {
      for_each = [for k8s_label in distinct(module.common.k8s_labels) : k8s_label]
      content {
        name = "properties.labels.${columns.value}"
        type = "string"
      }
    }
    dynamic "columns" {
      for_each = [for k8s_annotation in distinct(module.common.k8s_annotations) : k8s_annotation]
      content {
        name = "properties.annotations.${columns.value}"
        type = "string"
      }
    }
  }
}

resource "aws_glue_crawler" "kubecost_glue_crawler" {
  name          = "kubecost_crawler"
  database_name = aws_glue_catalog_database.kubecost_glue_db.name
  schedule      = "cron(${var.glue_crawler_schedule})"
  role          = aws_iam_role.kubecost_glue_crawler_role.name

  catalog_target {
    database_name = aws_glue_catalog_database.kubecost_glue_db.name
    tables = [
      aws_glue_catalog_table.kubecost_glue_table.name
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
# If the "kubecost_ca_certificate_path" variable contains a value, a secret containing the CA certificate will be created
# Else, it won't be created
resource "aws_secretsmanager_secret" "kubecost_ca_cert_secret" {
  count = length(module.common.kubecost_ca_certificates_list) > 0 ? length(module.common.kubecost_ca_certificates_list) : 0

  name                    = module.common.kubecost_ca_certificates_list[count.index].cert_secret_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "kubecost_ca_cert_content" {
  count = length(module.common.kubecost_ca_certificates_list) > 0 ? length(module.common.kubecost_ca_certificates_list) : 0

  secret_id     = aws_secretsmanager_secret.kubecost_ca_cert_secret[count.index].id
  secret_string = file(module.common.kubecost_ca_certificates_list[count.index].cert_path)
}

resource "aws_secretsmanager_secret_policy" "kubecost_ca_cert_secret_policy" {
  count = length(module.common.kubecost_ca_certificates_list) > 0 ? length(module.common.kubecost_ca_certificates_list) : 0

  secret_arn = aws_secretsmanager_secret.kubecost_ca_cert_secret[count.index].arn
  policy = templatefile("../modules/pipeline/secret_policy.tpl", {
    arn        = aws_secretsmanager_secret.kubecost_ca_cert_secret[count.index].id
    principals = module.common.kubecost_ca_certificates_list[count.index].cert_secret_allowed_principals
  })
}

resource "local_file" "cid_yaml" {
  filename             = "../../../cid/eks_insights_dashboard.yaml"
  directory_permission = "0400"
  file_permission      = "0400"
  content = templatefile("../../../cid/eks_insights_dashboard.yaml.tpl", {
    labels                = distinct(module.common.k8s_labels)
    annotations           = distinct(module.common.k8s_annotations)
    athena_datasource_arn = "$${athena_datasource_arn}"
    athena_database_name  = "$${athena_database_name}"
  })
}