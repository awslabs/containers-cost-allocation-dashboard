# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source = "../common"
}

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 4.63.0"
      configuration_aliases = [aws.pipeline, aws.eks]
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

data "aws_caller_identity" "pipeline_caller_identity" {
  provider = aws.pipeline
}

data "aws_secretsmanager_secret" "kubecost_secret" {
  provider = aws.pipeline
  count    = length(var.kubecost_ca_certificate_secret_name) > 0 ? 1 : 0

  name = var.kubecost_ca_certificate_secret_name
}

locals {
  cluster_region           = element(split(":", var.cluster_arn), 3)
  cluster_account_id       = element(split(":", var.cluster_arn), 4)
  cluster_name             = element(split("/", var.cluster_arn), 1)
  cluster_oidc_provider_id = element(split("/", var.cluster_oidc_provider_arn), 3)
  pipeline_partition       = element(split(":", data.aws_caller_identity.pipeline_caller_identity.arn), 1)
  pipeline_account_id      = data.aws_caller_identity.pipeline_caller_identity.account_id
  helm_chart_location      = "../../../helm/kubecost_s3_exporter"
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
        "role" : aws_iam_role.kubecost_s3_exporter_irsa_child_role.arn
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
          "value" : aws_iam_role.kubecost_s3_exporter_irsa_parent_role.arn
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
          "value" : var.kubecost_ca_certificate_secret_name
        },
        {
          "name" : "KUBECOST_CA_CERTIFICATE_SECRET_REGION",
          "value" : length(var.kubecost_ca_certificate_secret_name) > 0 ? element(split(":", data.aws_secretsmanager_secret.kubecost_secret[0].arn), 3) : ""
        },
        {
          "name" : "LABELS",
          "value" : try(join(", ", lookup(element(module.common.clusters_metadata, index(module.common.clusters_metadata.*.cluster_id, var.cluster_arn)), "labels", [])), "")
        },
        {
          "name" : "ANNOTATIONS",
          "value" : try(join(", ", lookup(element(module.common.clusters_metadata, index(module.common.clusters_metadata.*.cluster_id, var.cluster_arn)), "annotations", [])), "")
        },
        {
          "name" : "PYTHONUNBUFFERED",
          "value" : "1"
        }
      ]
    }
  )
}

resource "aws_iam_role" "kubecost_s3_exporter_irsa_child_role" {
  provider = aws.eks

  name = "kubecost_s3_exporter_irsa_${element(split("/", var.cluster_oidc_provider_arn), 3)}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Federated = var.cluster_oidc_provider_arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${element(split(":oidc-provider/", var.cluster_oidc_provider_arn), 1)}:aud" = "sts.amazonaws.com"
              "${element(split(":oidc-provider/", var.cluster_oidc_provider_arn), 1)}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
            }
          }
        }
      ]
    }
  )

  inline_policy {
    name = "kubecost_s3_exporter_irsa_${element(split("/", var.cluster_oidc_provider_arn), 3)}"
    policy = jsonencode(
      {
        Statement = [
          {
            Action   = "sts:AssumeRole"
            Effect   = "Allow"
            Resource = "arn:${local.pipeline_partition}:iam::${local.pipeline_account_id}:role/kubecost_s3_exporter_parent_${local.cluster_oidc_provider_id}"
          }
        ]
        Version = "2012-10-17"
      }
    )
  }
}

resource "aws_iam_role" "kubecost_s3_exporter_irsa_parent_role" {
  provider = aws.pipeline

  name = "kubecost_s3_exporter_parent_${local.cluster_oidc_provider_id}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            AWS = aws_iam_role.kubecost_s3_exporter_irsa_child_role.arn
          }
          Action = "sts:AssumeRole"
        }
      ]
    }
  )

  inline_policy {
    name = "kubecost_s3_exporter_parent_put_object"
    policy = jsonencode(
      {
        Statement = [
          {
            Action   = "s3:PutObject"
            Effect   = "Allow"
            Resource = "${module.common.bucket_arn}/account_id=${local.cluster_account_id}/region=${local.cluster_region}/year=*/month=*/*_${local.cluster_name}.snappy.parquet"
          }
        ]
        Version = "2012-10-17"
      }
    )
  }

  inline_policy {
    name = "kubecost_s3_exporter_parent_list_bucket"
    policy = jsonencode(
      {
        Statement = [
          {
            Action   = "s3:ListBucket"
            Effect   = "Allow"
            Resource = module.common.bucket_arn
          }
        ]
        Version = "2012-10-17"
      }
    )
  }

  # The below inline policy is conditionally created
  # If the "kubecost_ca_certificate_secret_name" variable contains a value, the below inline policy is added
  # Else, it won't be added
  dynamic "inline_policy" {
    for_each = length(var.kubecost_ca_certificate_secret_name) > 0 ? [1] : []
    content {
      name = "kubecost_s3_exporter_parent_get_secret_value"
      policy = jsonencode(
        {
          Statement = [
            {
              Action   = "secretsmanager:GetSecretValue"
              Effect   = "Allow"
              Resource = data.aws_secretsmanager_secret.kubecost_secret[0].arn
            }
          ]
          Version = "2012-10-17"
        }
      )
    }
  }

  tags = {
    irsa-kubecost-s3-exporter    = "true"
    irsa-kubecost-s3-exporter-sm = length(var.kubecost_ca_certificate_secret_name) > 0 ? "true" : "false"
  }
}

# The below 2 resources are conditionally created
# If the "invoke_helm" variable is set, the first resource ("helm_release") is created
# This deploys the K8s resources (data collection pod and service account) in the cluster by invoking Helm
# Else, the second resource ("local_file") is created
# This will NOT invoke Helm to deploy the K8s resources (data collection pod and service account) in the cluster
# Instead, it'll create a local values.yaml file in the Helm chart's directory, to be used by the user to deploy the K8s using the "helm" command
# The local file name will be "<cluster_account_id>_<cluster_region>_<cluster_name>_values.yaml", so it'll be unique

resource "helm_release" "kubecost_s3_exporter_helm_release" {
  count = var.invoke_helm ? 1 : 0

  name             = "kubecost-s3-exporter"
  chart            = local.helm_chart_location
  namespace        = var.namespace
  create_namespace = var.create_namespace
  values           = [local.helm_values_yaml]
}

resource "local_file" "kubecost_s3_exporter_helm_values_yaml" {
  count = var.invoke_helm ? 0 : 1

  filename             = "${local.helm_chart_location}/clusters_values/${local.cluster_account_id}_${local.cluster_region}_${local.cluster_name}_values.yaml"
  directory_permission = "0400"
  file_permission      = "0400"
  content              = <<-EOT
# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

${local.helm_values_yaml}
  EOT
}