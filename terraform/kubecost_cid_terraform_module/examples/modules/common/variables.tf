# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "bucket_arn" {
  description = "(Required) The ARN of the S3 Bucket to which the Kubecost data will be uploaded"
  type        = string
  default     = "arn:aws:s3:::kubecost-data-collection-bucket"

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

variable "aws_glue_view_name" {
  description = "(Optional) The AWS Glue Table name for the Athena view"
  type        = string
  default     = "kubecost_view"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.aws_glue_view_name))
    error_message = "The 'aws_glue_view_name' variable contains an invalid AWS Glue Table name"
  }
}

variable "aws_glue_crawler_name" {
  description = "(Optional) The AWS Glue Crawler name"
  type        = string
  default     = "kubecost_crawler"
  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.aws_glue_crawler_name))
    error_message = "The 'aws_glue_crawler_name' variable contains an invalid AWS Crawler Table name"
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
        for path in var.aws_shared_credentials_files : path
        if can(regex("^(~|\\/[ \\w.-]+)+$", path))
      ]) == length(var.aws_shared_credentials_files)
    )
    error_message = "At least one of the items the 'aws_shared_credentials_files' list, contains an invalid full file path"
  }
}

variable "k8s_labels" {
  description = "K8s labels common across all clusters, that you wish to include in the dataset"
  type        = list(string)
  default     = ["app", "chart", "component", "app.kubernetes.io/version", "app.kubernetes.io/managed_by", "app.kubernetes.io/part_of"]

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
  default     = ["kubernetes.io/psp", "eks.amazonaws.com/compute_type"]

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
  default = {
    test-tag1 = "test-value1"
    test-tag2 = "test-value2"
  }
}