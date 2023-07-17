# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "glue_crawler_schedule" {
  type        = string
  description = "The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule"

  validation {
    condition     = var.glue_crawler_schedule != ""
    error_message = "The 'glue_crawler_schedule' input is empty. It must contain a Cron expression"
  }
}