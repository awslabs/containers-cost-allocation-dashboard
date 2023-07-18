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
    error_message = "The 'bucket_arn' input contains an invalid ARN"
  }
}

variable "clusters_metadata" {
  description = <<EOF
    (Optional) A list of clusters and their additional metadata (K8s labels, annotations) that you wish to include in the dataset.
    Each item in the list has the following parameters:

    (Required) cluster_id: The unique ID of the K8s cluster (e.g., ARN for EKS cluster)
    (Optional) labels: A list of K8s labels you wish to include in the dataset
    (Optional) annotations: A list of K8s annotations you wish to include in the dataset

    Please note that there's no need to include a "cluster_id" field in the list if you don't need to add labels or annotations to the dataset for it.
    In other words, when adding a cluster to the list, add it with at least "labels" field or "annotations" field.
  EOF

  type = list(object({
    cluster_id  = string
    labels      = optional(list(string))
    annotations = optional(list(string))
  }))

  default = []

  validation {
    condition = (
      length([
        for cluster_id in var.clusters_metadata.*.cluster_id : cluster_id
        if can(regex("^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\\d:\\d{12}:cluster\\/[a-zA-Z0-9][a-zA-Z0-9-_]{1,99}$", cluster_id))
      ]) == length(var.clusters_metadata)
    )
    error_message = "At least one of the 'cluster_id' keys in the 'clusters_metadata' list, contains an invalid value"
  }
}

variable "athena_workgroup_configuration" {
  description = <<EOF
    (Optional) The configuration the Athena Workgroup. Used either to create a new Athena Workgroup, or reference configuration of an existing Athena Workgroup.

    (Required) create: Dictates whether to create a custom Athena Workgroup
    (Required) name: If "create" is "true", used to define the Athena Workgroup name and reference it in the QuickSight Data Source. If "create" is "false", used only for referencing the Workgroup in the QuickSight Data Source
    (Required when "create" is "true') query_results_location_bucket_name: If "create" is "true", used to set the Athena Workgroup query results location. If "create" is "false", this field is ignored
  EOF

  type = object({
    create                             = bool
    name                               = string
    query_results_location_bucket_name = optional(string, "")
  })

  default = {
    create                             = true
    name                               = "kubecost"
    query_results_location_bucket_name = "" # Add an S3 bucket name for Athena Workgroup Query Results Location, if "create" is "true"
  }

  validation {
    condition = (
      (
        var.athena_workgroup_configuration.create &&
        can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.athena_workgroup_configuration.query_results_location_bucket_name)) &&
        !startswith(var.athena_workgroup_configuration.query_results_location_bucket_name, "xn--") &&
        !endswith(var.athena_workgroup_configuration.query_results_location_bucket_name, "-s3alias") &&
        can(regex("^[A-Za-z0-9_.-]{1,128}$", var.athena_workgroup_configuration.name))
      )
      ||
      (
        !var.athena_workgroup_configuration.create &&
        can(regex("^[A-Za-z0-9_.-]{1,128}$", var.athena_workgroup_configuration.name))
      )
    )
    error_message = <<EOF
      The 'athena_workgroup_configuration' variable must have one of the following combinations:
1. When the 'create' field is 'true', the 'name' field must have a valid Athena Workgroup name, and the 'query_results_location_bucket_name' field must have a valid S3 bucket name
2. When the 'create' field is 'false', the 'name' field must have a valid Athena Workgroup name, and 'query_results_location_bucket_name' is ignored (so it can have any value)
    EOF
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
  description = "(Optional) Paths to the AWS shared config files"
  type        = list(string)
  default     = ["~/.aws/config"]

  # Here are a few examples of a "aws_shared_config_files" input that'll fail validation:
  # The "aws_shared_config_files" has an empty list: []
  # The "aws_shared_config_files" has a single empty item: [""]
  validation {
    condition     = length(compact(var.aws_shared_config_files)) > 0
    error_message = "The 'aws_shared_config_files' input is empty. It must contain at least one AWS shared config file"
  }
}

variable "aws_shared_credentials_files" {
  description = "(Optional) Paths to the AWS shared credentials files"
  type        = list(string)
  default     = ["~/.aws/credentials"]

  # Here are a few examples of a "aws_shared_credentials_files" input that'll fail validation:
  # The "aws_shared_credentials_files" has an empty list: []
  # The "aws_shared_credentials_files" has a single empty item: [""]
  validation {
    condition     = length(compact(var.aws_shared_credentials_files)) > 0
    error_message = "The 'aws_shared_credentials_files' input is empty. It must contain at least one AWS shared credentials file"
  }
}

variable "aws_common_tags" {
  description = "(Optional) Common AWS tags to be used on all AWS resources created by Terraform"
  type        = map(any)
  default     = {}
}