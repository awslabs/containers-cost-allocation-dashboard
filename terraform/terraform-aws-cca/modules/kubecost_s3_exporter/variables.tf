#                           #
# Common Module's Variables #
#                           #

variable "bucket_arn" {
  description = <<-EOF
    (Required) The ARN of the S3 Bucket to which the Kubecost data will be uploaded.
               Meant to only take a reference to the "bucket_arn" output from the common module.
               Possible values: Only "module.common.bucket_arn" (without the double quotes).
               Possible values: A valid S3 bucket ARN.
  EOF

  type = string

  # Note - the full regex should have been "^arn:(?:aws|aws-cn|aws-us-gov):s3:::(?!(xn--|.+-s3alias$))[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"
  # The "(?!(xn--|.+-s3alias$))" part has been omitted because Terraform regex engine doesn't support negative lookahead (the "?!" part)
  # Therefore, it has been removed, and instead, "!startswith" and "!endswith" conditions have been added, to complement this missing functionality
  validation {
    condition = (
      can(regex("^arn:(?:aws|aws-cn|aws-us-gov):s3:::[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_arn)) &&
      !startswith(element(split(":::", var.bucket_arn), 1), "xn--") &&
      !endswith(element(split(":::", var.bucket_arn), 1), "-s3alias")
    )
    error_message = "The 'bucket_arn' variable contains an invalid ARN"
  }
}

variable "k8s_labels" {
  description = <<-EOF
    (Optional) K8s labels common across all clusters, that you wish to include in the dataset.
               Meant to only take a reference to the "k8s_labels" output from the common module.
               Possible values: Only "module.common.k8s_labels" (without the double quotes).
               Default value: empty list ([]).
  EOF

  type    = list(string)
  default = []

  validation {
    condition = (
      length([
        for k8s_label in var.k8s_labels : k8s_label
        if can(regex("^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])\\/[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$|^[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$", k8s_label))
      ]) == length(var.k8s_labels)
    )
    error_message = "At least one of the items the 'k8s_labels' list, contains an invalid K8s label key"
  }
}

variable "k8s_annotations" {
  description = <<-EOF
    (Optional) K8s annotations common across all clusters, that you wish to include in the dataset.
               Meant to only take a reference to the "k8s_annotations" output from the common module.
               Possible values: Only "module.common.k8s_annotations" (without the double quotes).
               Default value: empty list ([]).
  EOF

  type    = list(string)
  default = []

  validation {
    condition = (
      length([
        for k8s_annotation in var.k8s_annotations : k8s_annotation
        if can(regex("^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])\\/[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$|^[a-zA-Z0-9][-\\w.]{0,61}[a-zA-Z0-9]$", k8s_annotation))
      ]) == length(var.k8s_annotations)
    )
    error_message = "At least one of the items the 'k8s_annotations' list, contains an invalid K8s annotation key"
  }
}

variable "aws_common_tags" {
  description = <<-EOF
    (Optional) Common AWS tags to be used on all AWS resources created by Terraform.
               Meant to only take a reference to the "aws_common_tags" output from the common module.
               Possible values: Only "module.common.aws_common_tags" (without the double quotes).
               Default value: empty map ({}).
  EOF

  type    = map(any)
  default = {}
}

#                           #
# Pipeline Module Variables #
#                           #

variable "kubecost_ca_certificate_secrets" {
  description = <<-EOF
    (Optional) A list of AWS Secret Manager secrets created by the pipeline module.
               Meant to only take a reference to the "kubecost_ca_cert_secret" output from the pipeline module.
               Possible values: Only "module.pipeline.kubecost_ca_cert_secret" (without the double quotes).
               Default value: empty list ([])
  EOF

  type    = list(any)
  default = []
}

#                         #
# This Module's Variables #
#                         #

variable "cluster_arn" {
  description = <<-EOF
    (Required) The EKS cluster ARN in which the Kubecost S3 Exporter pod will be deployed
               Possible values: EKS cluster ARN.
  EOF

  type = string

  validation {
    condition     = can(regex("^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\\d:\\d{12}:cluster\\/[a-zA-Z0-9][\\w-]{1,99}$", var.cluster_arn))
    error_message = "The 'cluster_arn' variable contains an invalid ARN"
  }
}

variable "kubecost_s3_exporter_container_image" {
  description = <<-EOF
    (Required) The Kubecost S3 Exporter container image.
               Possible values: A valid Docker image string.
  EOF

  type = string

  validation {
    condition     = can(regex("^((?:((?:(?:localhost|[\\w-]+(?:\\.[\\w-]+)+)(?::\\d+)?)|[\\w]+:\\d+)\\/)?\\/?((?:(?:[a-z0-9]+(?:(?:[._]|__|[-]*)[a-z0-9]+)*)\\/)*)([a-z0-9_-]+))[:@]?(([\\w][\\w.-]{0,127})|([A-Za-z][A-Za-z0-9]*(?:[-_+.][A-Za-z][A-Za-z0-9]*)*[:][0-9A-Fa-f]{32,}))?$", var.kubecost_s3_exporter_container_image))
    error_message = "The 'kubecost_s3_exporter_container_image' variable containers an invalid Docker container image string"
  }
}

variable "kubecost_s3_exporter_container_image_pull_policy" {
  description = <<-EOF
    (Optional) The image pull policy that will be used by the Kubecost S3 Exporter pod.
               Possible values: "Always", "IfNotPresent" or "Never".
               Default value: Always
  EOF

  type    = string
  default = "Always"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.kubecost_s3_exporter_container_image_pull_policy)
    error_message = "The 'kubecost_s3_exporter_container_image_pull_policy' variable includes an invalid value. It should be one of 'Always' or 'IfNotPresent' or 'Never'"
  }
}

variable "kubecost_s3_exporter_cronjob_schedule" {
  description = <<-EOF
    (Optional) The schedule of the Kubecost S3 Exporter CronJob.
               Possible values: A valid cron expression.
               Default value: 0 0 * * *
  EOF

  type    = string
  default = "0 0 * * *"

  validation {
    condition     = can(regex("(@(annually|yearly|monthly|weekly|daily|hourly|reboot))|(@every (\\d+(ns|us|µs|ms|s|m|h))+)|((((\\d+,)+\\d+|(\\d+([/\\-])\\d+)|\\d+|\\*) ?){5,7})", var.kubecost_s3_exporter_cronjob_schedule))
    error_message = "The 'kubecost_s3_exporter_cronjob_schedule' variable contains an invalid Cron expression"
  }
}

variable "kubecost_s3_exporter_ephemeral_volume_size" {
  description = <<-EOF
    (Optional) The ephemeral volume size for the Kubecost S3 Exporter pod.
               Possible values: Size in the format of 'NMi', where N >= 1. For example, 10Mi, 50Mi, 100Mi, 150Mi.
               Default value: 50Mi
  EOF

  type    = string
  default = "50Mi"

  validation {
    condition     = can(regex("^[1-9]\\d?Mi.*$", var.kubecost_s3_exporter_ephemeral_volume_size))
    error_message = "The 'kubecost_s3_exporter_ephemeral_volume_size' variable must be in format of 'NMi', where N >= 1.\nFor example, 10Mi, 50Mi, 100Mi, 150Mi."
  }
}

variable "kubecost_api_endpoint" {
  description = <<-EOF
    (Optional) The Kubecost API endpoint in format of 'http://<name_or_ip>:<port>'.
               Possible values: URI in the format of 'http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]'.
               Default value: http://kubecost-cost-analyzer.kubecost:9090
  EOF

  type    = string
  default = "http://kubecost-cost-analyzer.kubecost:9090"

  validation {
    condition     = can(regex("^https?://.+$", var.kubecost_api_endpoint))
    error_message = "The Kubecost API endpoint is invalid. It must be in the format of 'http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]'"
  }
}

variable "backfill_period_days" {
  description = <<-EOF
    (Optional) The number of days to check for backfilling.
               Possible values: A positive integer equal or larger than 3.
               Default value: 15
  EOF

  type    = number
  default = 15

  validation {
    condition     = var.backfill_period_days >= 3
    error_message = "The 'backfill_period_days' variable must be a positive integer equal to or larger than 3"
  }
}

variable "aggregation" {
  description = <<-EOF
    (Optional) The aggregation to use for returning the Kubecost Allocation API results.
               Possible values: "container", "pod", "namespace", "controller", "controllerKind", "node" or "cluster".
               Default value: container
  EOF

  type    = string
  default = "container"

  validation {
    condition     = contains(["container", "pod", "namespace", "controller", "controllerKind", "node", "cluster"], var.aggregation)
    error_message = "The 'aggregation' variable includes an invalid value. It should be one of 'container', 'pod', 'namespace', 'controller', 'controllerKind', 'node', or 'cluster'"
  }
}

variable "kubecost_allocation_api_paginate" {
  description = <<-EOF
    (Optional) Dictates whether to paginate using 1-hour time ranges (relevant for 1h step).
               Possible values: "Yes", "No", "Y", "N", "True" or "False"
               Default value: False
  EOF

  type    = string
  default = "False"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N|True|False)$", var.kubecost_allocation_api_paginate))
    error_message = "The 'kubecost_allocation_api_paginate' variable must be one of 'Yes', 'No', 'Y', 'N', 'True' or 'False' (case-insensitive)"
  }
}

variable "connection_timeout" {
  description = <<-EOF
    (Optional) The time (in seconds) to wait for TCP connection establishment.
               Possible values: A non-zero positive integer.
               Default value: 10
  EOF

  type    = number
  default = 10

  validation {
    condition     = var.connection_timeout > 0
    error_message = "The connection timeout must be a non-zero positive integer"
  }
}

variable "kubecost_allocation_api_read_timeout" {
  description = <<-EOF
    (Optional) The time (in seconds) to wait for the Kubecost Allocation API to send an HTTP response.
               Possible values: A non-zero positive integer.
               Default value: 60
  EOF

  type    = number
  default = 60

  validation {
    condition     = var.kubecost_allocation_api_read_timeout > 0
    error_message = "The read timeout must be a non-zero positive float"
  }
}

variable "tls_verify" {
  description = <<-EOF
    (Optional) Dictates whether TLS certificate verification is done for HTTPS connections.
               Possible values: "Yes", "No", "Y", "N", "True" or "False"
               Default value: True
  EOF

  type    = string
  default = "True"

  validation {
    condition     = can(regex("^(?i)(Yes|No|Y|N|True|False)$", var.tls_verify))
    error_message = "The 'tls_verify' variable must be one of 'Yes', 'No', 'Y', 'N', 'True' or 'False' (case-insensitive)"
  }
}

variable "kubecost_ca_certificate_secret_name" {
  description = <<-EOF
    (Optional) The AWS Secrets Manager secret name, for the CA certificate used for verifying Kubecost's server certificate when using HTTPS.
               Possible values: A valid AWS Secrets Manager secret name.
               Default value: empty string ("")
  EOF

  type    = string
  default = ""

  validation {
    condition     = can(regex("^$|^[\\w/+=.@-]{1,512}$", var.kubecost_ca_certificate_secret_name))
    error_message = "The 'kubecost_ca_certificate_secret_name' variable contains an invalid secret name"
  }
}

variable "namespace" {
  description = <<-EOF
    (Optional) The namespace in which the Kubecost S3 Exporter pod and service account will be created.
               Possible values: A valid K8s namespace name.
               Default value: kubecost-s3-exporter
  EOF

  type    = string
  default = "kubecost-s3-exporter"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,62}[a-z0-9])?$", var.namespace))
    error_message = "The 'namespace' variable contains an invalid Namespace name"
  }
}

variable "create_namespace" {
  description = <<-EOF
    (Optional) Dictates whether to create the namespace as part of the Helm Chart deployment.
               Possible values: true or false.
               Default value: true
  EOF

  type    = bool
  default = true
}

variable "service_account" {
  description = <<-EOF
    (Optional) The service account for the Kubecost S3 Exporter pod.
               Possible values: A valid K8s service account name.
               Default value: kubecost-s3-exporter
  EOF

  type    = string
  default = "kubecost-s3-exporter"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,252}[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?){0,252}$", var.service_account))
    error_message = "The 'service_account' variable contains an invalid Service Account name"
  }
}

variable "create_service_account" {
  description = <<-EOF
    (Optional) Dictates whether to create the service account as part of the Helm Chart deployment.
               Possible values: true or false.
               Default value: true
  EOF

  type    = bool
  default = true
}

variable "invoke_helm" {
  description = <<-EOF
    (Optional) Dictates whether to invoke Helm to deploy the K8s resources (the kubecost-s3-exporter CronJob and the Service Account).
               Possible values: true or false.
               Default value: true
  EOF

  type    = bool
  default = true
}