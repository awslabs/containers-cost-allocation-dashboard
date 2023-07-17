# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "bucket_arn" {
  type        = string
  default     = "arn:aws:s3:::kubecost-data-collection-bucket"
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"

  # The below validation validates the "bucket_arn" input.
  # It'll return the specified error if the input fails the validation.
  # Here are a few examples of a "bucket_arn" input that'll fail validation:
  # The "bucket_arn" key is empty ("")
  # The "bucket_arn" key has some unstructured string (e.g. "test")
  # The "bucket_arn" key has less than 6 ARN fields ("arn:aws:eks")
  # The bucket name part of the ARN doesn't match the bucket name rules
  # The "bucket_arn" input has missing ARN fields, has value in fields where there shouldn't be, or has incorrect value in some ARN fields. A few examples:
  # arn:aws:s3:us-east-1:111111111111:bucket_name
  # arn:aws:eks:::bucket_name
  # arn:aaa:s3:::bucket_name
  #
  # Note - the full regex should have been "^arn:(?:aws|aws-cn|aws-us-gov):s3:::(?!(xn--|.+-s3alias$))[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"
  # The "(?!(xn--|.+-s3alias$))" part has been omitted because Terraform regex engine doesn't support negative lookahead (the "?!" part)
  # Therefore, it has been removed, and instead, "!startswith" and "!endswith" conditions have been added, to complement this missing functionality
  validation {
    condition     = can(regex("^arn:(?:aws|aws-cn|aws-us-gov):s3:::[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_arn)) && !startswith(element(split(":::", var.bucket_arn), 1), "xn--") && !endswith(element(split(":::", var.bucket_arn), 1), "-s3alias")
    error_message = "The 'bucket_arn' input contains an invalid ARN"
  }
}

variable "clusters_metadata" {
  type = list(object({
    cluster_id  = string
    annotations = optional(list(string))
  }))

  default = [
    {
      "cluster_id" : "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      "labels" : ["app", "chart"]
      "annotations" : ["kubernetes.io/psp", "eks.amazonaws.com/compute_type"]
    },
    {
      "cluster_id" : "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
      "labels" : ["app", "chart"]
    },
    {
      "cluster_id" : "arn:aws:eks:us-east-2:111111111111:cluster/cluster1"
      "labels" : ["app", "chart", "env"]
    },
    {
      "cluster_id" : "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
      "labels" : ["app", "chart", "owner", "environment"]
    },
    {
      "cluster_id" : "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
      "labels" : ["app", "chart", "owner"]
    },
    {
      "cluster_id" : "arn:aws:eks:us-east-2:222222222222:cluster/cluster2"
      "labels" : ["app", "chart", "owner"]
    }
  ]

  description = "A map of clusters and their additional metadata (K8s labels, annotations) that you wish to include in the dataset"

  # The below validation validates each "cluster_arn" key's value in each object in the "clusters_labels" list.
  # It'll return the specified error if at least one of the "cluster_arn" keys' value fails the validation.
  # Here are a few examples of a "cluster_arn" key's value that'll fail validation:
  # The "cluster_arn" key's value is empty ("")
  # The "cluster_arn" key's value has some unstructured string (e.g. "test")
  # The "cluster_arn" key's value has less than 6 ARN fields ("arn:aws:eks")
  # The "cluster_arn" key's value has 6 ARN fields, but is missing the "/" before the resource ID ("arn:aws:eks:us-east-1:111111111111:cluster")
  # The EKS cluster name part of the ARN doesn't match the EKS cluster name rules
  # The "cluster_arn" key's value has missing ARN fields or has incorrect value in some ARN fields. A few examples:
  # arn:aws:eks:us-east-1:111111111111:cluster/
  # arn:aws:eks:us-east-1:123:cluster/cluster1
  # arn:aws:eks:us-east-1::cluster/cluster1
  # arn:aws:eks:aaa:111111111111:cluster/cluster1
  # arn:aws:eks::111111111111:cluster/cluster1
  # arn:aws:s3:us-east-1:111111111111:cluster/cluster1
  # arn:aaa:eks:us-east-1:111111111111:cluster/cluster1
  validation {
    condition     = length([for cluster_id in var.clusters_metadata.*.cluster_id : cluster_id if can(regex("^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\\d:\\d{12}:cluster\\/[a-zA-Z0-9][a-zA-Z0-9-_]{1,99}$", cluster_id))]) == length(var.clusters_metadata)
    error_message = "At least one of the 'cluster_id' keys in the 'clusters_metadata' list, contains an invalid value"
  }
}

variable "custom_athena_workgroup" {
  description = "The settings for the custom Athena Workgroup. This variable can either have 'create' field as 'true' with 'name' field containing a valid Athena Workgroup name and 'query_results_location_bucket_name' containing a valid S3 bucket name, or 'create' field as 'false'"

  type = object({
    create                             = bool                 # Dictates whether to create a custom Athena Workgroup
    name                               = optional(string, "") # If "create" is "true", used to define the Athena Workgroup name
    query_results_location_bucket_name = optional(string, "") # If "create" is "true", used to define the Athena Workgroup query results location S3 bucket name
  })

  default = {
    create                             = true
    name                               = "kubecost"
    query_results_location_bucket_name = "kubecost-query-results"
  }

  validation {
    condition     = (var.custom_athena_workgroup.create && can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.custom_athena_workgroup.query_results_location_bucket_name)) && !startswith(var.custom_athena_workgroup.query_results_location_bucket_name, "xn--") && !endswith(var.custom_athena_workgroup.query_results_location_bucket_name, "-s3alias")) && can(regex("^[A-Za-z0-9_.-]{1,128}$", var.custom_athena_workgroup.name)) || (!var.custom_athena_workgroup.create)
    error_message = "The 'custom_athena_workgroup' variable must have one of the following combinations:\n 1. When the 'create' field is 'true', the 'name' field must have a valid Athena Workgroup name, and the 'query_results_location_bucket_name' field must have a valid S3 bucket name\n 2. When the 'create' field is 'false', the 'name' and 'query_results_location_bucket_name' can have any value, as they're ignored"
  }
}

variable "kubecost_ca_certificates_list" {
  type = list(object({
    cert_path                      = string
    cert_secret_name               = string
    cert_secret_allowed_principals = optional(list(string))
  }))

  default = [
    {
      "cert_path" : "/tmp/certs/ca1.cert.pem"
      "cert_secret_name" : "cert_secret1"
      "cert_secret_allowed_principals" : ["arn:aws:iam::111111111111:role/role1", "arn:aws:iam::111111111111:role/role2"]
    },
    {
      "cert_path" : "/tmp/certs/ca2.cert.pem"
      "cert_secret_name" : "cert_secret2"
    }
  ]
  description = "A list of objects containing CA certificates paths and their desired secret name in AWS Secrets Manager"

  validation {
    condition     = length([for cert_secret_name in var.kubecost_ca_certificates_list.*.cert_secret_name : cert_secret_name if can(regex("^[a-z[A-Z0-9/_+=.@-]{1,512}$", cert_secret_name))]) == length(var.kubecost_ca_certificates_list)
    error_message = "At least one of the 'cert_secret_name' keys in the 'kubecost_ca_certificates_list' list, contains an invalid secret name"
  }
}

variable "aws_shared_config_files" {
  type        = list(string)
  default     = ["~/.aws/config"]
  description = "Paths to the AWS shared config files"

  # Here are a few examples of a "aws_shared_config_files" input that'll fail validation:
  # The "aws_shared_config_files" has an empty list: []
  # The "aws_shared_config_files" has a single empty item: [""]
  validation {
    condition     = length(compact(var.aws_shared_config_files)) > 0
    error_message = "The 'aws_shared_config_files' input is empty. It must contain at least one AWS shared config file"
  }
}

variable "aws_shared_credentials_files" {
  type        = list(string)
  default     = ["~/.aws/credentials"]
  description = "Paths to the AWS shared credentials files"

  # Here are a few examples of a "aws_shared_credentials_files" input that'll fail validation:
  # The "aws_shared_credentials_files" has an empty list: []
  # The "aws_shared_credentials_files" has a single empty item: [""]
  validation {
    condition     = length(compact(var.aws_shared_credentials_files)) > 0
    error_message = "The 'aws_shared_credentials_files' input is empty. It must contain at least one AWS shared credentials file"
  }
}

variable "aws_common_tags" {
  type = map(any)
  default = {
    test-tag1 = "test-value1"
    test-tag2 = "test-value2"
  }
  description = "Common AWS tags to be used on all AWS resources created by Terraform"
}