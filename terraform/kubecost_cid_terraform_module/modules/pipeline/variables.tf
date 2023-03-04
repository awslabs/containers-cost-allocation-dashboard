# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "aws_region" {
  type        = string
  description = "The AWS region code to use for the pipeline resources"
}

variable "aws_profile" {
  type        = string
  description = "The AWS profile to use for configuration and credentials to create the pipeline resources"
}

variable "glue_crawler_schedule" {
  type        = string
  description = "The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule"
}