locals {
  bucket_name                        = element(split(":::", var.bucket_arn), 1)
  cluster_name                       = element(split("/", data.aws_arn.eks_cluster.resource), 1)
  cluster_oidc_provider_id           = element(split("/", data.aws_iam_openid_connect_provider.this.arn), 3)
  pipeline_partition                 = element(split(":", data.aws_caller_identity.pipeline.arn), 1)
  kubecost_ca_certificate_secret_arn = length(var.kubecost_ca_certificate_secrets) > 0 ? lookup(element(var.kubecost_ca_certificate_secrets, index(var.kubecost_ca_certificate_secrets.*.name, var.kubecost_ca_certificate_secret_name)), "arn", "") : ""
  helm_chart_location                = "${path.module}/../../../../helm/kubecost_s3_exporter"
  helm_values_yaml = yamlencode(
    {
      "namespace" : var.namespace
      "image" : var.kubecost_s3_exporter_container_image
      "imagePullPolicy" : var.kubecost_s3_exporter_container_image_pull_policy
      "ephemeralVolumeSize" : var.kubecost_s3_exporter_ephemeral_volume_size
      "cronJob" : {
        "name" : "kubecost-s3-exporter",
        "schedule" : var.kubecost_s3_exporter_cronjob_schedule
      }
      "serviceAccount" : {
        "name" : var.service_account
        "create" : var.create_service_account
        "role" : length(aws_iam_role.kubecost_s3_exporter_irsa_child) > 0 ? aws_iam_role.kubecost_s3_exporter_irsa_child[0].arn : aws_iam_role.kubecost_s3_exporter_irsa[0].arn
      }
      "env" : [
        {
          "name" : "S3_BUCKET_NAME",
          "value" : local.bucket_name
        },
        {
          "name" : "KUBECOST_API_ENDPOINT",
          "value" : var.kubecost_api_endpoint
        },
        {
          "name" : "BACKFILL_PERIOD_DAYS",
          "value" : var.backfill_period_days
        },
        {
          "name" : "CLUSTER_ID",
          "value" : var.cluster_arn
        },
        {
          "name" : "IRSA_PARENT_IAM_ROLE_ARN",
          "value" : length(aws_iam_role.kubecost_s3_exporter_irsa_parent) > 0 ? aws_iam_role.kubecost_s3_exporter_irsa_parent[0].arn : ""
        },
        {
          "name" : "AGGREGATION",
          "value" : var.aggregation
        },
        {
          "name" : "KUBECOST_ALLOCATION_API_PAGINATE",
          "value" : var.kubecost_allocation_api_paginate
        },
        {
          "name" : "CONNECTION_TIMEOUT",
          "value" : var.connection_timeout
        },
        {
          "name" : "KUBECOST_ALLOCATION_API_READ_TIMEOUT",
          "value" : var.kubecost_allocation_api_read_timeout
        },
        {
          "name" : "TLS_VERIFY",
          "value" : var.tls_verify
        },
        {
          "name" : "KUBECOST_CA_CERTIFICATE_SECRET_NAME",
          "value" : length(local.kubecost_ca_certificate_secret_arn) > 0 ? var.kubecost_ca_certificate_secret_name : ""
        },
        {
          "name" : "KUBECOST_CA_CERTIFICATE_SECRET_REGION",
          "value" : length(local.kubecost_ca_certificate_secret_arn) > 0 ? element(split(":", local.kubecost_ca_certificate_secret_arn), 3) : ""
        },
        {
          "name" : "LABELS",
          "value" : join(", ", distinct(var.k8s_labels))
        },
        {
          "name" : "ANNOTATIONS",
          "value" : join(", ", distinct(var.k8s_annotations))
        },
        {
          "name" : "PYTHONUNBUFFERED",
          "value" : "1"
        }
      ]
    }
  )
}