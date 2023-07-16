# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "glue_crawler_schedule" {
  type        = string
  description = "The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule"

  validation {
    condition     = var.glue_crawler_schedule != ""
    error_message = "The 'glue_crawler_schedule' input is empty. It must contain a Cron expression"
  }
}

variable "custom_athena_workgroup" {
  type = object({
    create                             = optional(bool, true)
    query_results_location_bucket_name = optional(string, "")
  })

  description = "The settings for the custom Athena Workgroup. This variable can either have 'create' field as 'true' with 'query_results_location_bucket_name' containing a valid S3 bucket name, or 'create' field as 'false'"

  validation {
    condition     = (var.custom_athena_workgroup.create && can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.custom_athena_workgroup.query_results_location_bucket_name)) && !startswith(var.custom_athena_workgroup.query_results_location_bucket_name, "xn--") && !endswith(var.custom_athena_workgroup.query_results_location_bucket_name, "-s3alias")) || (!var.custom_athena_workgroup.create)
    error_message = "The 'custom_athena_workgroup' variable must either have 'create' field as 'true' and a valid S3 bucket name in 'query_results_location_bucket_name' field, or 'create' field as 'false'"
  }
}