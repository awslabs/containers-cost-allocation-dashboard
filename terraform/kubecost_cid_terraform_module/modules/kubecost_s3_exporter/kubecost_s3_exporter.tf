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

data "aws_caller_identity" "eks_caller_identity" {
  provider = aws.eks
}

data "aws_eks_cluster" "cluster" {
  provider = aws.eks

  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "oidc" {
  provider = aws.eks

  url = data.aws_eks_cluster.cluster.identity.0.oidc.0.issuer
}

# The below resource is created conditionally, if the EKS cluster account ID and the pipeline account ID are the same
# This means that a single IAM Role (IRSA) is created in the account, as cross-account authentication isn't required
resource "aws_iam_role" "kubecost_s3_exporter_irsa_role" {
  provider = aws.eks

  count = data.aws_caller_identity.eks_caller_identity.account_id == data.aws_caller_identity.pipeline_caller_identity.account_id ? 1 : 0

  name = "kubecost_s3_exporter_irsa_${local.cluster_oidc_provider_id}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Federated = data.aws_iam_openid_connect_provider.oidc.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${element(split(":oidc-provider/", data.aws_iam_openid_connect_provider.oidc.arn), 1)}:aud" = "sts.amazonaws.com"
              "${element(split(":oidc-provider/", data.aws_iam_openid_connect_provider.oidc.arn), 1)}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
            }
          }
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
  # If the "kubecost_ca_certificate_secret_arn" local contains a value, the below inline policy is added
  # Else, it won't be added
  dynamic "inline_policy" {
    for_each = length(local.kubecost_ca_certificate_secret_arn) > 0 ? [1] : []
    content {
      name = "kubecost_s3_exporter_parent_get_secret_value"
      policy = jsonencode(
        {
          Statement = [
            {
              Action   = "secretsmanager:GetSecretValue"
              Effect   = "Allow"
              Resource = local.kubecost_ca_certificate_secret_arn
            }
          ]
          Version = "2012-10-17"
        }
      )
    }
  }

  tags = {
    irsa-kubecost-s3-exporter    = "true"
    irsa-kubecost-s3-exporter-sm = length(local.kubecost_ca_certificate_secret_arn) > 0 ? "true" : "false"
  }
}

# The below 2 resources are created conditionally, if the EKS cluster account ID and the pipeline account ID are different
# This means that a child IAM Role (IRSA) is created in the EKS account, and a parent IAM role is created in the pipeline accoubt
# This is for cross-account authentication using IAM Role Chaining
resource "aws_iam_role" "kubecost_s3_exporter_irsa_child_role" {
  provider = aws.eks

  count = data.aws_caller_identity.eks_caller_identity.account_id != data.aws_caller_identity.pipeline_caller_identity.account_id ? 1 : 0

  name = "kubecost_s3_exporter_irsa_${local.cluster_oidc_provider_id}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            Federated = data.aws_iam_openid_connect_provider.oidc.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${element(split(":oidc-provider/", data.aws_iam_openid_connect_provider.oidc.arn), 1)}:aud" = "sts.amazonaws.com"
              "${element(split(":oidc-provider/", data.aws_iam_openid_connect_provider.oidc.arn), 1)}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
            }
          }
        }
      ]
    }
  )

  inline_policy {
    name = "kubecost_s3_exporter_irsa_${local.cluster_oidc_provider_id}"
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

  count = data.aws_caller_identity.eks_caller_identity.account_id != data.aws_caller_identity.pipeline_caller_identity.account_id ? 1 : 0

  name = "kubecost_s3_exporter_parent_${local.cluster_oidc_provider_id}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Principal = {
            AWS = aws_iam_role.kubecost_s3_exporter_irsa_child_role[0].arn
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
  # If the "kubecost_ca_certificate_secret_arn" local contains a value, the below inline policy is added
  # Else, it won't be added
  dynamic "inline_policy" {
    for_each = length(local.kubecost_ca_certificate_secret_arn) > 0 ? [1] : []
    content {
      name = "kubecost_s3_exporter_parent_get_secret_value"
      policy = jsonencode(
        {
          Statement = [
            {
              Action   = "secretsmanager:GetSecretValue"
              Effect   = "Allow"
              Resource = local.kubecost_ca_certificate_secret_arn
            }
          ]
          Version = "2012-10-17"
        }
      )
    }
  }

  tags = {
    irsa-kubecost-s3-exporter    = "true"
    irsa-kubecost-s3-exporter-sm = length(local.kubecost_ca_certificate_secret_arn) > 0 ? "true" : "false"
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