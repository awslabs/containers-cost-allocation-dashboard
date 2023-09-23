# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "cluster_arn" {
  description = "(Required) The EKS cluster ARN in which the Kubecost S3 Exporter pod will be deployed"
  type        = string

  validation {
    condition     = can(regex("^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\\d:\\d{12}:cluster\\/[a-zA-Z0-9][\\w-]{1,99}$", var.cluster_arn))
    error_message = "The 'cluster_arn' variable contains an invalid ARN"
  }
}

variable "kubecost_s3_exporter_container_image" {
  description = "(Required) The Kubecost S3 Exporter container image"
  type        = string

  validation {
    condition     = can(regex("^((?:((?:(?:localhost|[\\w-]+(?:\\.[\\w-]+)+)(?::\\d+)?)|[\\w]+:\\d+)\\/)?\\/?((?:(?:[a-z0-9]+(?:(?:[._]|__|[-]*)[a-z0-9]+)*)\\/)*)([a-z0-9_-]+))[:@]?(([\\w][\\w.-]{0,127})|([A-Za-z][A-Za-z0-9]*(?:[-_+.][A-Za-z][A-Za-z0-9]*)*[:][0-9A-Fa-f]{32,}))?$", var.kubecost_s3_exporter_container_image))
    error_message = "The 'kubecost_s3_exporter_container_image' variable containers an invalid Docker container image string"
  }
}

variable "kubecost_s3_exporter_container_image_pull_policy" {
  description = "(Optional) The image pull policy that'll be used by the Kubecost S3 Exporter pod"
  type        = string
  default     = "Always"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.kubecost_s3_exporter_container_image_pull_policy)
    error_message = "The 'kubecost_s3_exporter_container_image_pull_policy' variable includes an invalid value. It should be one of 'Always' or 'IfNotPresent' or 'Never'"
  }
}

variable "kubecost_s3_exporter_cronjob_schedule" {
  description = "(Optional) The schedule of the Kubecost S3 Exporter CronJob"
  type        = string
  default     = "0 0 * * *"

  validation {
    condition     = can(regex("(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\\d+(ns|us|µs|ms|s|m|h))+)|((((\\d+,)+\\d+|(\\d+([/\\-])\\d+)|\\d+|\\*) ?){5,7})", var.kubecost_s3_exporter_cronjob_schedule))
    error_message = "The 'kubecost_s3_exporter_cronjob_schedule' variable contains an invalid Cron expression"
  }
}

variable "kubecost_s3_exporter_ephemeral_volume_size" {
  description = "(Optional) The ephemeral volume size for the Kubecost S3 Exporter pod"
  type        = string
  default     = "50Mi"

  validation {
    condition     = can(regex("^[1-9]\\d?Mi.*$", var.kubecost_s3_exporter_ephemeral_volume_size))
    error_message = "The 'kubecost_s3_exporter_ephemeral_volume_size' variable must be in format of 'NMi', where N >= 1.\nFor example, 10Mi, 50Mi, 100Mi, 150Mi."
  }
}

variable "kubecost_api_endpoint" {
  description = "(Optional) The Kubecost API endpoint in format of 'http://<name_or_ip>:<port>'"
  type        = string
  default     = "http://kubecost-cost-analyzer.kubecost:9090"

  validation {
    condition     = can(regex("^https?://.+$", var.kubecost_api_endpoint))
    error_message = "The Kubecost API endpoint is invalid. It must be in the format of 'http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]'"
  }
}

variable "backfill_period_days" {
  description = "(Optional) The number of days to check for backfilling"
  type        = number
  default     = 15

  validation {
    condition     = var.backfill_period_days >= 3
    error_message = "The 'backfill_period_days' variable must be a positive integer equal to or larger than 3"
  }
}

variable "aggregation" {
  description = "(Optional) The aggregation to use for returning the Kubecost Allocation API results"
  type        = string
  default     = "container"

  validation {
    condition     = contains(["container", "pod", "namespace", "controller", "controllerKind", "node", "cluster"], var.aggregation)
    error_message = "The 'aggregation' variable includes an invalid value. It should be one of 'container', 'pod', 'namespace', 'controller', 'controllerKind', 'node', or 'cluster'"
  }
}

variable "kubecost_allocation_api_paginate" {
  description = "(Optional) Dictates whether to paginate using 1-hour time ranges (relevant for 1h step)"
  type        = string
  default     = "False"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N|True|False)$", var.kubecost_allocation_api_paginate))
    error_message = "The 'kubecost_allocation_api_paginate' variable must be one of 'Yes', 'No', 'Y', 'N', 'True' or 'False' (case-insensitive)"
  }
}

variable "connection_timeout" {
  description = "(Optional) The time (in seconds) to wait for TCP connection establishment"
  type        = number
  default     = 10

  validation {
    condition     = var.connection_timeout > 0
    error_message = "The connection timeout must be a non-zero positive integer"
  }
}

variable "kubecost_allocation_api_read_timeout" {
  description = "(Optional) The time (in seconds) to wait for the Kubecost Allocation API to send an HTTP response"
  type        = number
  default     = 60

  validation {
    condition     = var.kubecost_allocation_api_read_timeout > 0
    error_message = "The read timeout must be a non-zero positive float"
  }
}

variable "tls_verify" {
  description = "(Optional) Dictates whether TLS certificate verification is done for HTTPS connections"
  type        = string
  default     = "True"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N|True|False)$", var.tls_verify))
    error_message = "The 'tls_verify' variable must be one of 'Yes', 'No', 'Y', 'N', 'True' or 'False' (case-insensitive)"
  }
}

variable "kubecost_ca_certificate_secrets" {
  description = "(Optional) A list of AWS Secret Manager secrets created by the pipeline module"
  type        = list(any)
  default     = []
}

variable "kubecost_ca_certificate_secret_name" {
  description = "(Optional) The AWS Secrets Manager secret name, for the CA certificate used for verifying Kubecost's server certificate when using HTTPS"
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^$|^[\\w/+=.@-]{1,512}$", var.kubecost_ca_certificate_secret_name))
    error_message = "The 'kubecost_ca_certificate_secret_name' variable contains an invalid secret name"
  }
}

variable "k8s_config_path" {
  description = "(Optional) Full path to the K8s config file, to be used by Helm"
  type        = string
  default     = "~/.kube/config"

  validation {
    condition     = can(regex("^(~|\\/[ \\w.-]+)+$", var.k8s_config_path))
    error_message = "The 'k8s_config_path' variable contains an invalid full file path"
  }
}

variable "namespace" {
  description = "(Optional) The namespace in which the Kubecost S3 Exporter pod and service account will be created"
  type        = string
  default     = "kubecost-s3-exporter"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,62}[a-z0-9])?$", var.namespace))
    error_message = "The 'namespace' variable contains an invalid Namespace name"
  }
}

variable "create_namespace" {
  description = "(Optional) Dictates whether to create the namespace as part of the Helm Chart deployment"
  type        = bool
  default     = true
}

variable "service_account" {
  description = "(Optional) The service account for the Kubecost S3 Exporter pod"
  type        = string
  default     = "kubecost-s3-exporter"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,252}[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?){0,252}$", var.service_account))
    error_message = "The 'service_account' variable contains an invalid Service Account name"
  }
}

variable "create_service_account" {
  description = "(Optional) Dictates whether to create the service account as part of the Helm Chart deployment"
  type        = bool
  default     = true
}

variable "invoke_helm" {
  description = "(Optional) Dictates whether to invoke Helm to deploy the K8s resources (the kubecost-s3-exporter CronJob and the Service Account)"
  type        = bool
  default     = true
}