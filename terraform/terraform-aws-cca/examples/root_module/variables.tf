variable "bucket_arn" {
  description = <<-EOF
    (Required) The ARN of the S3 Bucket to which the Kubecost data will be uploaded.
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
               Possible values: A list of strings, each one should be a valid K8s label key.
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
               Possible values: A list of strings, each one should be a valid K8s annotation key.
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
               Possible values: Each field in the map must have a valid AWS tag key and an optional value.
               Default value: empty map ({}).
  EOF

  type    = map(any)
  default = {}
}