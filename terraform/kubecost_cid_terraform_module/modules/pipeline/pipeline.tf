# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source = "../common"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<= 4.63.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "<= 2.4.0"
    }
  }
}

locals {
  # A set of locals used to gather all labels and annotations from all K8s clusters, and create a distinct list of labels and annotations
  # This is used to define those labels and annotations as columns in the AWS Glue Table
  distinct_labels        = distinct(flatten([for labels_list in module.common.clusters_metadata.*.labels : labels_list == null ? [] : labels_list]))
  distinct_annotations   = distinct(flatten([for annotations_list in module.common.clusters_metadata.*.annotations : annotations_list == null ? [] : annotations_list]))
  labels_for_output      = join(", ", local.distinct_labels)
  annotations_for_output = join(", ", local.distinct_annotations)
}

# This data source is used conditionally, only if the "create" field in the "custom_athena_workgroup" variable is "true"
data "aws_kms_key" "s3_kms" {
  count = module.common.athena_workgroup_configuration.create ? 1 : 0

  key_id = "alias/aws/s3"
}

# This resource is created conditionally, only if the "create" field in the "custom_athena_workgroup" variable is "true"
resource "aws_athena_workgroup" "kubecost_athena_workgroup" {
  count = module.common.athena_workgroup_configuration.create ? 1 : 0

  name          = module.common.athena_workgroup_configuration.name
  force_destroy = true

  configuration {
    result_configuration {
      output_location = "s3://${module.common.athena_workgroup_configuration.query_results_location_bucket_name}/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = data.aws_kms_key.s3_kms[count.index].arn
      }
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
  name = "kubecost_db"
}

resource "aws_glue_catalog_table" "kubecost_glue_table" {
  name          = "kubecost_table"
  database_name = aws_glue_catalog_database.kubecost_glue_db.name
  parameters = {
    "classification" = "parquet"
  }

  table_type = "EXTERNAL_TABLE"

  partition_keys {
    name = "account_id"
    type = "string"
  }
  partition_keys {
    name = "region"
    type = "string"
  }
  partition_keys {
    name = "year"
    type = "string"
  }
  partition_keys {
    name = "month"
    type = "string"
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

    columns {
      name = "name"
      type = "string"
    }

    columns {
      name = "window.start"
      type = "timestamp"
    }

    columns {
      name = "window.end"
      type = "timestamp"
    }

    columns {
      name = "minutes"
      type = "double"
    }

    columns {
      name = "cpucores"
      type = "double"
    }
    columns {
      name = "cpucorerequestaverage"
      type = "double"
    }
    columns {
      name = "cpucoreusageaverage"
      type = "double"
    }
    columns {
      name = "cpucorehours"
      type = "double"
    }
    columns {
      name = "cpucost"
      type = "double"
    }
    columns {
      name = "cpucostadjustment"
      type = "double"
    }
    columns {
      name = "cpuefficiency"
      type = "double"
    }
    columns {
      name = "gpucount"
      type = "double"
    }
    columns {
      name = "gpuhours"
      type = "double"
    }
    columns {
      name = "gpucost"
      type = "double"
    }
    columns {
      name = "gpucostadjustment"
      type = "double"
    }
    columns {
      name = "networktransferbytes"
      type = "double"
    }
    columns {
      name = "networkreceivebytes"
      type = "double"
    }
    columns {
      name = "networkcost"
      type = "double"
    }
    columns {
      name = "networkcrosszonecost"
      type = "double"
    }
    columns {
      name = "networkcrossregioncost"
      type = "double"
    }
    columns {
      name = "networkinternetcost"
      type = "double"
    }
    columns {
      name = "networkcostadjustment"
      type = "double"
    }
    columns {
      name = "loadbalancercost"
      type = "double"
    }
    columns {
      name = "loadbalancercostadjustment"
      type = "double"
    }
    columns {
      name = "pvbytes"
      type = "double"
    }
    columns {
      name = "pvbytehours"
      type = "double"
    }
    columns {
      name = "pvcost"
      type = "double"
    }
    columns {
      name = "pvcostadjustment"
      type = "double"
    }
    columns {
      name = "rambytes"
      type = "double"
    }
    columns {
      name = "rambyterequestaverage"
      type = "double"
    }
    columns {
      name = "rambyteusageaverage"
      type = "double"
    }
    columns {
      name = "rambytehours"
      type = "double"
    }
    columns {
      name = "ramcost"
      type = "double"
    }
    columns {
      name = "ramcostadjustment"
      type = "double"
    }
    columns {
      name = "ramefficiency"
      type = "double"
    }
    columns {
      name = "sharedcost"
      type = "double"
    }
    columns {
      name = "externalcost"
      type = "double"
    }
    columns {
      name = "totalcost"
      type = "double"
    }
    columns {
      name = "totalefficiency"
      type = "double"
    }
    columns {
      name = "properties.provider"
      type = "string"
    }
    columns {
      name = "properties.region"
      type = "string"
    }
    columns {
      name = "properties.cluster"
      type = "string"
    }
    columns {
      name = "properties.clusterid"
      type = "string"
    }
    columns {
      name = "properties.eksclustername"
      type = "string"
    }
    columns {
      name = "properties.container"
      type = "string"
    }
    columns {
      name = "properties.namespace"
      type = "string"
    }
    columns {
      name = "properties.pod"
      type = "string"
    }
    columns {
      name = "properties.node"
      type = "string"
    }
    columns {
      name = "properties.node_instance_type"
      type = "string"
    }
    columns {
      name = "properties.node_availability_zone"
      type = "string"
    }
    columns {
      name = "properties.node_capacity_type"
      type = "string"
    }
    columns {
      name = "properties.node_architecture"
      type = "string"
    }
    columns {
      name = "properties.node_os"
      type = "string"
    }
    columns {
      name = "properties.node_nodegroup"
      type = "string"
    }
    columns {
      name = "properties.node_nodegroup_image"
      type = "string"
    }
    columns {
      name = "properties.controller"
      type = "string"
    }
    columns {
      name = "properties.controllerkind"
      type = "string"
    }
    columns {
      name = "properties.providerid"
      type = "string"
    }
    dynamic "columns" {
      for_each = [for k8s_label in local.distinct_labels : k8s_label]
      content {
        name = "properties.labels.${columns.value}"
        type = "string"
      }
    }
    dynamic "columns" {
      for_each = [for k8s_annotation in local.distinct_annotations : k8s_annotation]
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

  secret_id     = aws_secretsmanager_secret.kubecost_ca_cert_secret[0].id
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
    labels                = local.distinct_labels
    annotations           = local.distinct_annotations
    athena_datasource_arn = "$${athena_datasource_arn}"
    athena_database_name  = "$${athena_database_name}"
  })
}