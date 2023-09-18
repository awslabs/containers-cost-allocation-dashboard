# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "bucket_arn" {
  description = "(Required) The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
  type        = string
  default     = "" # Add an S3 Bucket ARN

  # Note - the full regex should have been "^arn:(?:aws|aws-cn|aws-us-gov):s3:::(?!(xn--|.+-s3alias$))[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"
  # The "(?!(xn--|.+-s3alias$))" part has been omitted because Terraform regex engine doesn't support negative lookahead (the "?!" part)
  # Therefore, it has been removed, and instead, "!startswith" and "!endswith" conditions have been added, to complement this missing functionality
  validation {
    condition = (
      can(regex("^arn:(?:aws|aws-cn|aws-us-gov):s3:::[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_arn)) &&
      !startswith(element(split(":::", var.bucket_arn), 1), "xn--") &&
      !endswith(element(split(":::", var.bucket_arn), 1), "-s3alias")
    )
    error_message = "The 'bucket_arn' variable contains an invalid ARN"
  }
}

variable "aws_glue_database_name" {
  description = "(Optional) The AWS Glue Database name"
  type        = string
  default     = "kubecost_db"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.aws_glue_database_name))
    error_message = "The 'aws_glue_database_name' variable contains an invalid AWS Glue Database name"
  }
}

variable "aws_glue_table_name" {
  description = "(Optional) The AWS Glue Table name"
  type        = string
  default     = "kubecost_table"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.aws_glue_table_name))
    error_message = "The 'aws_glue_table_name' variable contains an invalid AWS Glue Table name"
  }
}

variable "kubecost_ca_certificates_list" {
  description = <<EOF
    (Optional) A list root CA certificates paths and their configuration for AWS Secrets Manager. Used for TLS communication with Kubecost. This is a consolidated list of all root CA certificates that are needed for all Kubecost endpoints.

    (Required) cert_path: The full local path to the root CA certificate
    (Required) cert_secret_name: The name to use for the AWS Secrets Manager Secret that will be created for this root CA certificate
    (Optional) cert_secret_allowed_principals: A list of principals to include in the AWS Secrets Manager Secret policy (in addition to the principal that identify the cluster, which will be automatically added by Terraform)
  EOF

  type = list(object({
    cert_path                      = string
    cert_secret_name               = string
    cert_secret_allowed_principals = optional(list(string))
  }))

  default = []

  validation {
    condition = (
      length([
        for cert_secret_name in var.kubecost_ca_certificates_list.*.cert_secret_name : cert_secret_name
        if can(regex("^[a-z[A-Z0-9/_+=.@-]{1,512}$", cert_secret_name))
      ]) == length(var.kubecost_ca_certificates_list)
    )
    error_message = "At least one of the 'cert_secret_name' keys in the 'kubecost_ca_certificates_list' list, contains an invalid secret name"
  }
}

variable "aws_shared_config_files" {
  description = "(Optional) Full paths to the AWS shared config files"
  type        = list(string)
  default     = ["~/.aws/config"]

  validation {
    condition = (
      length([
        for path in var.aws_shared_config_files : path
        if can(regex("^(~|\\/[ \\w.-]+)+$", path))
      ]) == length(var.aws_shared_config_files)
    )
    error_message = "At least one of the items the 'aws_shared_config_files' list, contains an invalid full file path"
  }
}

variable "aws_shared_credentials_files" {
  description = "(Optional) Full paths to the AWS shared credentials files"
  type        = list(string)
  default     = ["~/.aws/credentials"]

  validation {
    condition = (
      length([
        for cert_secret_name in var.kubecost_ca_certificates_list.*.cert_secret_name : cert_secret_name
        if can(regex("^[\\w/+=.@-]{1,512}$", cert_secret_name))
      ]) == length(var.kubecost_ca_certificates_list)
    )
    error_message = "At least one of the 'cert_secret_name' keys in the 'kubecost_ca_certificates_list' list, contains an invalid secret name"
  }
}

variable "k8s_labels" {
  description = "K8s labels common across all clusters, that you wish to include in the dataset"
  type        = list(string)
  default     = []

  validation {
    condition = (
      length([
        for k8s_label in var.k8s_labels : k8s_label
        if can(regex("^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])\\/[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$|^[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$", k8s_label))
      ]) == length(var.k8s_labels)
    )
    error_message = "At least one of the items the 'k8s_labels' list, contains an invalid K8s label key"
  }
}

variable "k8s_annotations" {
  description = "K8s annotations common across all clusters, that you wish to include in the dataset"
  type        = list(string)
  default     = []

  validation {
    condition = (
      length([
        for k8s_annotation in var.k8s_annotations : k8s_annotation
        if can(regex("^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])\\/[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$|^[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$", k8s_annotation))
      ]) == length(var.k8s_annotations)
    )
    error_message = "At least one of the items the 'k8s_annotations' list, contains an invalid K8s annotation key"
  }
}

variable "aws_common_tags" {
  description = "(Optional) Common AWS tags to be used on all AWS resources created by Terraform"
  type        = map(any)
  default     = {}
}