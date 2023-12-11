# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "glue_database_name" {
  description = <<-EOF
    (Optional) The AWS Glue database name.
               Possible values: A valid AWS Glue database name.
               Default value: kubecost_db
  EOF

  type    = string
  default = "kubecost_db"

  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.glue_database_name))
    error_message = "The 'glue_database_name' variable contains an invalid AWS Glue Database name"
  }
}

variable "glue_table_name" {
  description = <<-EOF
    (Optional) The AWS Glue table name.
               Possible values: A valid AWS Glue table name.
               Default value: kubecost_table
  EOF

  type    = string
  default = "kubecost_table"

  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.glue_table_name))
    error_message = "The 'glue_table_name' variable contains an invalid AWS Glue Table name"
  }
}

variable "glue_view_name" {
  description = <<-EOF
    (Optional) The AWS Glue Table name for the Athena view
               Possible values: A valid AWS Glue table name.
               Default value: kubecost_view
  EOF

  type    = string
  default = "kubecost_view"

  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.glue_view_name))
    error_message = "The 'glue_view_name' variable contains an invalid AWS Glue Table name"
  }
}

variable "glue_crawler_name" {
  description = <<-EOF
    (Optional) The AWS Glue Crawler name
               Possible values: A valid AWS Glue crawler name.
               Default value: kubecost_crawler
  EOF

  type    = string
  default = "kubecost_crawler"

  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.glue_crawler_name))
    error_message = "The 'glue_crawler_name' variable contains an invalid AWS Crawler Table name"
  }
}

variable "glue_crawler_schedule" {
  description = <<-EOF
    (Optional) The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule.
               Possible values: A valid cron expression.
               Default value: 0 1 * * ? *

  EOF

  type    = string
  default = "0 1 * * ? *"

  validation {
    condition     = can(regex("(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\\d+(ns|us|µs|ms|s|m|h))+)|((((\\d+,)+\\d+|(\\d+([/\\-])\\d+)|\\d+|\\*|\\?) ?){5,7})", var.glue_crawler_schedule))
    error_message = "The 'glue_crawler_schedule' variable contains an invalid Cron expression"
  }
}

variable "athena_view_data_retention_months" {
  description = <<-EOF
    (Optional) The amount of months back to keep data in the Athena view.
               Possible values: A non-zero positive integer.
               Default value: 6
  EOF

  type    = string
  default = 6

  validation {
    condition     = can(regex("^[1-9][0-9]*$", var.athena_view_data_retention_months))
    error_message = "The 'athena_view_data_retention_months' variable can take only a non-zero positive integer"
  }
}

variable "kubecost_ca_certificates_list" {
  description = <<-EOF
    (Optional) A list root CA certificates paths and their configuration for AWS Secrets Manager. Used for TLS communication with Kubecost.
               This is a consolidated list of all root CA certificates that are needed for all Kubecost endpoints.

               (Required) cert_path: The full local path to the root CA certificate.
                                     Possible values: A valid Linux path.
               (Required) cert_secret_name: The name to use for the AWS Secrets Manager Secret that will be created for this root CA certificate.
                                            Possible values: A valid AWS Secret Manager secret name.
               (Optional) cert_secret_allowed_principals: A list of principals to include in the AWS Secrets Manager Secret policy (in addition to the principal that identify the cluster, which will be automatically added by Terraform).
                                                          Possible values: A list of IAM principals (users, roles) ARNs.
                                                          Default value: empty list ([]).
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