# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

locals {
  cluster_region                     = element(split(":", var.cluster_arn), 3)
  cluster_account_id                 = element(split(":", var.cluster_arn), 4)
  cluster_name                       = element(split("/", var.cluster_arn), 1)
  cluster_oidc_provider_id           = element(split("/", data.aws_iam_openid_connect_provider.oidc.arn), 3)
  pipeline_partition                 = element(split(":", data.aws_caller_identity.pipeline_caller_identity.arn), 1)
  pipeline_account_id                = data.aws_caller_identity.pipeline_caller_identity.account_id
  kubecost_ca_certificate_secret_arn = length(var.kubecost_ca_certificate_secrets) > 0 ? lookup(element(var.kubecost_ca_certificate_secrets, index(var.kubecost_ca_certificate_secrets.*.name, var.kubecost_ca_certificate_secret_name)), "arn", "") : ""
  helm_chart_location                = "../../../helm/kubecost_s3_exporter"
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
        "role" : length(aws_iam_role.kubecost_s3_exporter_irsa_child_role) > 0 ? aws_iam_role.kubecost_s3_exporter_irsa_child_role[0].arn : aws_iam_role.kubecost_s3_exporter_irsa_role[0].arn
      }
      "env" : [
        {
          "name" : "S3_BUCKET_NAME",
          "value" : element(split(":::", module.common.bucket_arn), 1)
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
          "value" : length(aws_iam_role.kubecost_s3_exporter_irsa_parent_role) > 0 ? aws_iam_role.kubecost_s3_exporter_irsa_parent_role[0].arn : ""
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
          "value" : join(", ", distinct(module.common.k8s_labels))
        },
        {
          "name" : "ANNOTATIONS",
          "value" : join(", ", distinct(module.common.k8s_annotations))
        },
        {
          "name" : "PYTHONUNBUFFERED",
          "value" : "1"
        }
      ]
    }
  )
}