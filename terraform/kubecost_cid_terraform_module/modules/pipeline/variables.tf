# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "aws_region" {
  type        = string
  description = "The AWS region code to use for the pipeline resources"

  validation {
    condition = can(regex("(us(-gov)?|ap|ca|cn|eu|sa)-(central|(north|south)?(east|west)?)-\\d", var.aws_region))
    error_message = "The 'aws_region' contains an invalid region-code"
  }
}

variable "aws_profile" {
  type        = string
  description = "The AWS profile to use for configuration and credentials to create the pipeline resources"

  validation {
    condition = var.aws_profile != ""
    error_message = "The 'aws_profile' input is empty. It must contain an AWS Profile name"
  }
}

variable "glue_crawler_schedule" {
  type        = string
  description = "The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule"

  validation {
    condition = var.glue_crawler_schedule != ""
    error_message = "The 'glue_crawler_schedule' input is empty. It must contain a Cron expression"
  }
}