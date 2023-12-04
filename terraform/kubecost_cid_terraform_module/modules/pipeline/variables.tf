# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "glue_crawler_schedule" {
  description = "(Required) The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule"
  type        = string

  validation {
    condition     = can(regex("(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\\d+(ns|us|µs|ms|s|m|h))+)|((((\\d+,)+\\d+|(\\d+([/\\-])\\d+)|\\d+|\\*|\\?) ?){5,7})", var.glue_crawler_schedule))
    error_message = "The 'glue_crawler_schedule' variable contains an invalid Cron expression"
  }
}

variable "athena_view_data_retention_months" {
  description = "(Optional) The amount of months back to keep data in the Athena view"
  type        = string
  default     = 6
  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.athena_view_data_retention_months))
    error_message = "The 'athena_view_data_retention_months' variable can take only a non-zero positive integer"
  }
}

variable "kubecost_ca_certificates_list" {
  description = <<-EOF
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
        for cert_path in var.kubecost_ca_certificates_list.*.cert_path : cert_path
        if can(regex("^(~|\\/[ \\w.-]+)+$", cert_path))
      ]) == length(var.kubecost_ca_certificates_list) &&
      length([
        for cert_secret_name in var.kubecost_ca_certificates_list.*.cert_secret_name : cert_secret_name
        if can(regex("^[\\w/+=.@-]{1,512}$", cert_secret_name))
      ]) == length(var.kubecost_ca_certificates_list)
    )
    error_message = <<-EOF
      At least one of the below is invalid in one of the items in "kubecost_ca_certificates_list" list:
      1. One of the "cert_path" values
      2. One of the "cert_secret_name" values
    EOF
  }
}