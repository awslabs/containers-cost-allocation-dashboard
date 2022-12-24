resource "aws_iam_policy" "kubecost_s3_exporter_service_account_policy" {
  name = "${local.name}-kubecost-s3-exporter"
  policy = jsonencode(
    {
      Statement = [
        {
          Action   = "s3:PutObject"
          Effect   = "Allow"
          Resource = "${local.bucket_arn}*"
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
  name = "${local.name}-kubecost-s3-exporter"
}

resource "aws_glue_catalog_database" "kubecost_s3_exporter_glue_db" {
  name = "${local.name}-kubecost-db"
}

resource "aws_glue_catalog_table" "kubecost_s3_exporter_glue_table" {
  name          = "${local.name}-kubecost-table"
  database_name = aws_glue_catalog_database.kubecost_s3_exporter_glue_db.name
  parameters = {
    "classification"         = "csv"
    "delimiter"              = ","
    "skip.header.line.count" = "1"
  }

  table_type = "EXTERNAL_TABLE"

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
      name                  = "${local.name}-kubecost-table-serde"
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

resource "helm_release" "kubecost_s3_exporter_helm_release" {
  name             = "${local.name}-kubecost-s3-exporter"
  chart            = "../../helm/kubecost-s3-exporter"
  namespace        = local.k8s_namespace
  create_namespace = local.k8s_create_namespace
  values = [yamlencode(
    {
      "image" : local.image
      "imagePullPolicy" : local.image_pull_policy
      "cronJob" : {
        "name" : "${local.name}-kubecost-s3-exporter",
        "schedule" : local.schedule
      }
      "serviceAccount" : {
        "create" : true,
        "name" : local.k8s_service_account
        "role" : aws_iam_role.kubecost_s3_exporter_service_account_role.arn
      }
      "env" : [
        {
          "name" : "S3_BUCKET_NAME",
          "value" : "${element(split(":::", local.bucket_arn), 1)}"
        },
        {
          "name" : "KUBECOST_API_ENDPOINT",
          "value" : local.kubecost_api_endpoint
        },
        {
          "name" : "CLUSTER_ID",
          "value" : local.cluster_id
        },
        {
          "name" : "GRANULARITY",
          "value" : local.granularity
        },
        {
          "name" : "LABELS",
          "value" : join(", ", local.k8s_labels)
        },
        {
          "name" : "PYTHONUNBUFFERED",
          "value" : "1"
        }
      ]
    }
  )]
}