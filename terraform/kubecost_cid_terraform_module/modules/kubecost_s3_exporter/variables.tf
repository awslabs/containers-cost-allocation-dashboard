# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "cluster_arn" {
  type        = string
  description = "The EKS cluster ARN in which the Kubecost S3 Exporter pod will be deployed"

  # The below validation validates the "cluster_arn" input.
  # It'll return the specified error if the input fails the validation.
  # Here are a few examples of a "cluster_arn" input that'll fail validation:
  # The "cluster_arn" input is empty ("")
  # The "cluster_arn" input has some unstructured string (e.g. "test")
  # The "cluster_arn" input has less than 6 ARN fields ("arn:aws:eks")
  # The "cluster_arn" input has 6 ARN fields, but is missing the "/" before the resource ID ("arn:aws:eks:us-east-1:111111111111:cluster")
  # The EKS cluster name part of the ARN doesn't match the EKS cluster name rules
  # The "cluster_arn" input has missing ARN fields or has incorrect value in some ARN fields. A few examples:
  # arn:aws:eks:us-east-1:111111111111:cluster/
  # arn:aws:eks:us-east-1:123:cluster/cluster1
  # arn:aws:eks:us-east-1::cluster/cluster1
  # arn:aws:eks:aaa:111111111111:cluster/cluster1
  # arn:aws:eks::111111111111:cluster/cluster1
  # arn:aws:s3:us-east-1:111111111111:cluster/cluster1
  # arn:aaa:eks:us-east-1:111111111111:cluster/cluster1
  validation {
    condition     = can(regex("^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\\d:\\d{12}:cluster\\/[a-zA-Z0-9][a-zA-Z0-9-_]{1,99}$", var.cluster_arn))
    error_message = "The 'cluster_arn' input contains an invalid ARN"
  }
}

variable "cluster_oidc_provider_arn" {
  type        = string
  description = "The IAM OIDC Provider ARN for the EKS cluster"

  # The below validation validates the "cluster_oidc_provider_arn" input.
  # It'll return the specified error if the input fails the validation.
  # Here are a few examples of a "cluster_arn" input that'll fail validation:
  # The "cluster_oidc_provider_arn" input is empty ("")
  # The "cluster_oidc_provider_arn" input has some unstructured string (e.g. "test")
  # The "cluster_oidc_provider_arn" input has less than 6 ARN fields ("arn:aws:eks")
  # The "cluster_oidc_provider_arn" input has 6 ARN fields, but is missing the "/" characters and the resource ID path ("arn:aws:iam::333333333333:oidc-provider)
  # The OIDC Provider ID part of the ARN doesn't match the convention (Hexadecimal ID)
  # The "cluster_oidc_provider_arn" input has missing ARN fields or has incorrect value in some ARN fields. A few examples:
  # arn:aws:iam::333333333333:oidc-provider/
  # arn:aws:iam:us-east-1::oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/123
  # arn:aws:iam::3333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/123
  # arn:aws:s3::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/123
  # arn:aaa:iam::333333333333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/123
  validation {
    condition     = can(regex("^arn:(?:aws|aws-cn|aws-us-gov):iam::\\d{12}:oidc-provider\\/oidc\\.eks\\.(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\\d\\.amazonaws\\.com\\/id\\/[A-F0-9]*$", var.cluster_oidc_provider_arn))
    error_message = "The 'cluster_oidc_provider_arn' input contains an invalid ARN"
  }
}

variable "kubecost_s3_exporter_container_image" {
  type        = string
  description = "The Kubecost S3 Exporter container image"

  validation {
    condition     = var.kubecost_s3_exporter_container_image != ""
    error_message = "The 'kubecost_s3_exporter_container_image' input is empty. It must contain a Docker container image string"
  }
}

variable "kubecost_s3_exporter_container_image_pull_policy" {
  type        = string
  default     = "Always"
  description = "The image pull policy that'll be used by the Kubecost S3 Exporter pod"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.kubecost_s3_exporter_container_image_pull_policy)
    error_message = "The 'kubecost_s3_exporter_container_image_pull_policy' input includes an invalid value. It should be one of 'Always' or 'IfNotPresent' or 'Never'"
  }
}

variable "kubecost_s3_exporter_cronjob_schedule" {
  type        = string
  default     = "0 0 * * *"
  description = "The schedule of the Kubecost S3 Exporter CronJob"

  validation {
    condition     = can(regex("(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\\d+(ns|us|µs|ms|s|m|h))+)|((((\\d+,)+\\d+|(\\d+([/\\-])\\d+)|\\d+|\\*) ?){5,7})", var.kubecost_s3_exporter_cronjob_schedule))
    error_message = "The 'kubecost_s3_exporter_cronjob_schedule' input contains an invalid Cron expression"
  }
}

variable "kubecost_s3_exporter_ephemeral_volume_size" {
  type        = string
  default     = "50Mi"
  description = "The ephemeral volume size for the Kubecost S3 Exporter pod"

  validation {
    condition     = can(regex("^[1-9][0-9]?Mi.*$", var.kubecost_s3_exporter_ephemeral_volume_size))
    error_message = "The 'kubecost_s3_exporter_ephemeral_volume_size' input must be in format of 'NMi', where N >= 1.\nFor example, 10Mi, 50Mi, 100Mi, 150Mi."
  }
}

variable "kubecost_api_endpoint" {
  type        = string
  default     = "http://kubecost-cost-analyzer.kubecost:9090"
  description = "The Kubecost API endpoint in format of 'http://<name_or_ip>:<port>'"

  validation {
    condition     = can(regex("^https?://.+$", var.kubecost_api_endpoint))
    error_message = "The Kubecost API endpoint is invalid. It must be in the format of 'http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]'"
  }
}

variable "backfill_period_days" {
  type        = number
  default     = 15
  description = "The number of days to check for backfilling"

  validation {
    condition     = var.backfill_period_days >= 3
    error_message = "The 'backfill_period_days' input must be a positive integer equal to or larger than 3"
  }
}

variable "aggregation" {
  type        = string
  default     = "container"
  description = "The aggregation to use for returning the Kubecost Allocation API results"

  validation {
    condition     = contains(["container", "pod", "namespace", "controller", "controllerKind", "node", "cluster"], var.aggregation)
    error_message = "The 'aggregation' input includes an invalid value. It should be one of 'container', 'pod', 'namespace', 'controller', 'controllerKind', 'node', or 'cluster'"
  }
}

variable "share_tenancy_costs" {
  type        = string
  default     = "Yes"
  description = "Dictates whether to include shared tenancy costs in the 'sharedCost' field"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N)$", var.share_tenancy_costs))
    error_message = "The 'share_tenancy_costs' input must be one of 'Yes', 'No', 'Y' or 'N' (case-insensitive)"
  }
}

variable "kubecost_allocation_api_paginate" {
  type        = string
  default     = "No"
  description = "Dictates whether to paginate using 1-hour time ranges (relevant for 1h step)"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N)$", var.kubecost_allocation_api_paginate))
    error_message = "The 'kubecost_allocation_api_paginate' input must be one of 'Yes', 'No', 'Y' or 'N' (case-insensitive)"
  }
}

variable "kubecost_allocation_api_resolution" {
  type        = string
  default     = "1m"
  description = "The Kubecost Allocation On-demand API resolution, to control accuracy vs performance"

  validation {
    condition     = can(regex("^[1-9][0-9]?m.*$", var.kubecost_allocation_api_resolution))
    error_message = "The 'kubecost_allocation_api_resolution' input must be in format of 'Nm', where N >= 1.\nFor example, 1m, 2m, 5m, 10m."
  }
}

variable "connection_timeout" {
  type        = number
  default     = 10
  description = "The time (in seconds) to wait for TCP connection establishment"

  validation {
    condition     = var.connection_timeout > 0
    error_message = "The connection timeout must be a non-zero positive integer"
  }
}

variable "kubecost_allocation_api_read_timeout" {
  type        = number
  default     = 60
  description = "The time (in seconds) to wait for the Kubecost Allocation On-Demand API to send an HTTP response"

  validation {
    condition     = var.kubecost_allocation_api_read_timeout > 0
    error_message = "The read timeout must be a non-zero positive float"
  }
}

variable "kubecost_assets_api_read_timeout" {
  type        = number
  default     = 30
  description = "The time (in seconds) to wait for the Kubecost Assets API to send an HTTP response"

  validation {
    condition     = var.kubecost_assets_api_read_timeout > 0
    error_message = "The read timeout must be a non-zero positive float"
  }
}

variable "tls_verify" {
  type        = string
  default     = "Yes"
  description = "Dictates whether TLS certificate verification is done for HTTPS connections"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N)$", var.tls_verify))
    error_message = "The 'tls_verify' input must be one of 'Yes', 'No', 'Y' or 'N' (case-insensitive)"
  }
}

variable "kubecost_ca_certificate_secret_name" {
  type        = string
  default     = ""
  description = "The AWS Secrets Manager secret name, for the CA certificate used for verifying Kubecost's server certificate when using HTTPS"

  validation {
    condition     = can(regex("^$|^[a-z[A-Z0-9/_+=.@-]{1,512}$", var.kubecost_ca_certificate_secret_name))
    error_message = "The 'kubecost_ca_certificate_secret_name' input contains an invalid secret name"
  }
}

variable "k8s_config_path" {
  type        = string
  default     = "~/.kube/config"
  description = "The K8s config file to be used by Helm"

  validation {
    condition     = var.k8s_config_path != ""
    error_message = "The 'k8s_config_path' input is empty. It must contain a K8s kubeconfig file"
  }
}

variable "namespace" {
  type        = string
  default     = "kubecost-s3-exporter"
  description = "The namespace in which the Kubecost S3 Exporter pod and service account will be created"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,252}$", var.namespace))
    error_message = "The 'namespace' input contains an invalid Namespace name"
  }
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Dictates whether to create the namespace as part of the Helm Chart deployment"
}

variable "service_account" {
  type        = string
  default     = "kubecost-s3-exporter"
  description = "The service account for the Kubecost S3 Exporter pod"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,252}$", var.service_account))
    error_message = "The 'service_account' input contains an invalid Service Account name"
  }
}

variable "create_service_account" {
  type        = bool
  default     = true
  description = "Dictates whether to create the service account as part of the Helm Chart deployment"
}

variable "invoke_helm" {
  type        = bool
  default     = true
  description = "Dictates whether to invoke Helm to deploy the K8s resources (the kubecost-s3-exporter CronJob and the Service Account)"
}