# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common" {
  source   = "../common"
}

resource "aws_iam_role" "kubecost_s3_exporter_service_account_role" {

  provider = aws.irsa

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
          Action   = "s3:PutObject"
          Effect   = "Allow"
          Resource = "${module.common.bucket_arn}/account_id=${element(split(":", var.cluster_arn), 4)}/region=${var.aws_region}/year=*/month=*/*_${element(split("/", var.cluster_arn), 1)}.snappy.parquet"
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

resource "helm_release" "kubecost_s3_exporter_helm_release" {

  name             = "kubecost-s3-exporter"
  chart            = "../../../../helm/my_helm/kubecost_s3_exporter"
  namespace        = var.namespace
  create_namespace = var.create_namespace
  values = [yamlencode(
    {
      "namespace": var.namespace
      "image": var.kubecost_s3_exporter_container_image
      "imagePullPolicy" : var.kubecost_s3_exporter_container_image_pull_policy
      "cronJob": {
        "name": "kubecost-s3-exporter",
        "schedule" : var.kubecost_s3_exporter_cronjob_schedule
      }
      "serviceAccount" : {
        "name": var.service_account
        "create": var.create_service_account
        "role": aws_iam_role.kubecost_s3_exporter_service_account_role.arn
      }
      "env": [
        {
          "name": "S3_BUCKET_NAME",
          "value": element(split(":::", module.common.bucket_arn), 1)
        },
        {
          "name": "KUBECOST_API_ENDPOINT",
          "value": var.kubecost_api_endpoint
        },
        {
          "name": "CLUSTER_ARN",
          "value": var.cluster_arn
        },
        {
          "name": "GRANULARITY",
          "value": module.common.granularity
        },
        {
          "name": "LABELS",
          "value": try(join(", ", lookup(element(module.common.clusters_labels, index(module.common.clusters_labels.*.cluster_arn, var.cluster_arn)), "labels", [])), "")
        },
        {
          "name": "PYTHONUNBUFFERED",
          "value": "1"
        }
      ]
    }
  )]
}