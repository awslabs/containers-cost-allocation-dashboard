resource "aws_cloudwatch_log_group" "kubecost_glue_crawler_log_group" {
  name = "kubecost_glue_crawler_log_group"
}

resource "aws_cloudwatch_log_stream" "kubecost_glue_crawler_log_stream" {
  name           = "kubecost_glue_crawler_log_stream"
  log_group_name = aws_cloudwatch_log_group.kubecost_glue_crawler_log_group.name
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
            "glue:BatchGetPartition",
            "glue:BatchCreatePartition",
          ]
          Effect = "Allow"
          Resource = [
            "${element(split("database/", aws_glue_catalog_database.kubecost_glue_db.arn), 0)}catalog",
            aws_glue_catalog_database.kubecost_glue_db.arn,
            aws_glue_catalog_table.kubecost_glue_table.arn
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
            "${local.bucket_arn}/*",
            local.bucket_arn,
          ]
          Sid = "AllowS3KubecostBucket"
        },
        {
          Action   = "logs:PutLogEvents"
          Effect   = "Allow"
          Resource = aws_cloudwatch_log_group.kubecost_glue_crawler_log_group.arn
          Sid      = "AllowCloudWatchLogsPutLogs"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role" "kubecost_glue_crawler_role" {
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
  name = "kubecost_glue_crawler_role"
}

resource "aws_glue_catalog_database" "kubecost_glue_db" {
  name = "kubecost_db"
}

resource "aws_glue_catalog_table" "kubecost_glue_table" {
  name          = "kubecost_table"
  database_name = aws_glue_catalog_database.kubecost_glue_db.name
  parameters = {
    "classification"         = "csv"
    "delimiter"              = ","
    "skip.header.line.count" = "1"
  }

  table_type = "EXTERNAL_TABLE"

  partition_keys {
    name = "year"
    type = "int"
  }
  partition_keys {
    name = "month"
    type = "int"
  }

  storage_descriptor {
    location      = "s3://${element(split(":::", local.bucket_arn), 1)}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    parameters = {
      "classification"         = "csv"
      "delimiter"              = ","
      "skip.header.line.count" = "1"
    }

    ser_de_info {
      name                  = "kubecost_table_serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim" = ","
      }
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
      name = "rawallocationonly"
      type = "double"
    }
    columns {
      name = "properties.cluster"
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
      for_each = [for k8s_label in local.k8s_labels : k8s_label]
      content {
        name = "properties.labels.${columns.value}"
        type = "string"
      }
    }
  }
}

resource "aws_glue_crawler" "kubecost_glue_crawler" {
  name          = "kubecost_crawler"
  database_name = aws_glue_catalog_database.kubecost_glue_db.name
  schedule      = "cron(0 ${element(split(" ", local.schedule), 1) + 1} * * ? *)"
  role          = aws_iam_role.kubecost_glue_crawler_role.name

  catalog_target {
    database_name = aws_glue_catalog_database.kubecost_glue_db.name
    tables = [
      aws_glue_catalog_table.kubecost_glue_table.name,
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

resource "aws_iam_policy" "kubecost_s3_exporter_service_account_policy" {
  name = "kubecost_s3_exporter_service_account_policy"
  policy = jsonencode(
    {
      Statement = [
        {
          Action   = "s3:PutObject"
          Effect   = "Allow"
          Resource = "${local.bucket_arn}/*"
        },
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role" "kubecost_s3_exporter_service_account_role" {
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${element(split(":oidc-provider/", local.eks_oidc_url), 1)}:aud" = "sts.amazonaws.com"
              "${element(split(":oidc-provider/", local.eks_oidc_url), 1)}:sub" = "system:serviceaccount:${local.k8s_namespace}:${local.k8s_service_account}"
            }
          }
          Effect = "Allow"
          Principal = {
            Federated = "${local.eks_oidc_url}"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  managed_policy_arns = [
    aws_iam_policy.kubecost_s3_exporter_service_account_policy.arn,
  ]
  name = "kubecost_s3_exporter_service_account_role"
}