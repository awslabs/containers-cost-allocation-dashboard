# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source = "../common"
}

data "aws_caller_identity" "irsa_parent_role_caller_identity" {
  provider = aws.irsa_parent_role
}

locals {

  cluster_account_id          = element(split(":", var.cluster_arn), 4)
  cluster_name                = element(split("/", var.cluster_arn), 1)
  cluster_oidc_provider_id    = element(split("/", var.cluster_oidc_provider_arn), 3)
  irsa_parent_role_partition  = element(split(":", data.aws_caller_identity.irsa_parent_role_caller_identity.arn), 1)
  irsa_parent_role_account_id = data.aws_caller_identity.irsa_parent_role_caller_identity.account_id
  helm_chart_location         = "../../../helm/kubecost_s3_exporter"
  helm_values_yaml = yamlencode(
    {
      "namespace" : var.namespace
      "image" : var.kubecost_s3_exporter_container_image
      "imagePullPolicy" : var.kubecost_s3_exporter_container_image_pull_policy
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
          "name" : "CLUSTER_ID",
          "value" : var.cluster_arn
        },
        {
          "name" : "IRSA_PARENT_IAM_ROLE_ARN",
          "value" : aws_iam_role.kubecost_s3_exporter_irsa_parent_role.arn
        },
        {
          "name" : "GRANULARITY",
          "value" : module.common.granularity
        },
        {
          "name" : "AGGREGATION",
          "value" : var.aggregation
        },
        {
          "name" : "LABELS",
          "value" : try(join(", ", lookup(element(module.common.clusters_labels, index(module.common.clusters_labels.*.cluster_id, var.cluster_arn)), "labels", [])), "")
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
            Resource = "arn:${local.irsa_parent_role_partition}:iam::${local.irsa_parent_role_account_id}:role/kubecost_s3_exporter_parent_${local.cluster_oidc_provider_id}"
          }
        ]
        Version = "2012-10-17"
      }
    )
  }
}

resource "aws_iam_role" "kubecost_s3_exporter_irsa_parent_role" {

  provider = aws.irsa_parent_role

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
    name = "kubecost_s3_exporter_parent_${local.cluster_oidc_provider_id}"
    policy = jsonencode(
      {
        Statement = [
          {
            Action   = "s3:PutObject"
            Effect   = "Allow"
            Resource = "${module.common.bucket_arn}/account_id=${local.cluster_account_id}/region=${var.aws_region}/year=*/month=*/*_${local.cluster_name}.snappy.parquet"
          }
        ]
        Version = "2012-10-17"
      }
    )
  }

  tags = {
    irsa-kubecost-s3-exporter = "true"
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

  filename             = "${local.helm_chart_location}/clusters_values/${local.cluster_account_id}_${var.aws_region}_${local.cluster_name}_values.yaml"
  directory_permission = "0400"
  file_permission      = "0400"
  content              = <<-EOT
# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

${local.helm_values_yaml}
  EOT
}