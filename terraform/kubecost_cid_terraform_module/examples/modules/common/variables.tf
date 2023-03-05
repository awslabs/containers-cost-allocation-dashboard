# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "bucket_arn" {
  type        = string
  default     = "arn:aws:s3:::kubecost-data-collection-bucket"
  description = "The ARN of the S3 Bucket to which the Kubecost data will be uploaded"

  # Use-cases for the below input validation:
  # The "bucket_arn" input is empty ("")
  # The "bucket_arn" input has some unstructured string ("test")
  # The "bucket_arn" input has less than 6 fields ("arn:aws:s3")
  validation {
    condition = length(split(":", var.bucket_arn)) == 6
    error_message = "The 'bucket_arn' input contains an invalid ARN"
  }

  # Example of an invalid input for the below validation: arn:aaa:s3:::bucket1
  validation {
    condition = contains(["aws", "aws-cn", "aws-us-gov"], element(split(":", var.bucket_arn), 1))
    error_message = "The 'bucket_arn' input includes an invalid partition field. The ARN partition field should be one of 'aws', 'aws-cn' or 'aws-us-gov'"
  }

  # Example of an invalid input for the below validation: arn:aws:eks:::bucket1
  validation {
    condition = element(split(":", var.bucket_arn), 2) == "s3"
    error_message = "The 'bucket_arn' input includes an invalid service field. The ARN service field should be 's3'"
  }

  # Example of an invalid input for the below validation: arn:aws:s3:us-east-1::bucket1
  validation {
    condition = element(split(":", var.bucket_arn), 3) == ""
    error_message = "The 'bucket_arn' input includes a region, but the region field for an S3 bucket ARN must be empty"
  }

  # Example of an invalid input for the below validation: arn:aws:s3::111111111111:bucket1
  validation {
    condition = element(split(":", var.bucket_arn), 4) == ""
    error_message = "The 'bucket_arn' input includes an account ID, but the account ID field for an S3 bucket ARN must be empty"
  }

  # Example of an invalid input for the below validation: arn:aws:s3:::
  validation {
    condition = element(split(":", var.bucket_arn), 5) != ""
    error_message = "The 'bucket_arn' input's resource ID field is empty. It must contain the bucket name"
  }
}

variable "irsa_aws_profile" {
  type        = string
  default     = "s3_bucket_account_aws_profile"
  description = "The AWS profile to use for configuration and credentials to create the IRSA in the S3 bucket's account"

  validation {
    condition = var.irsa_aws_profile != ""
    error_message = "The 'irsa_aws_profile' input is empty. It must contain an AWS Profile name"
  }
}

variable "clusters_labels" {

  type = list(object({
    cluster_arn = string
    labels      = optional(list(string))
  }))

  default = [
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      "labels" : ["app", "chart"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
      "labels" : ["app", "chart"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-2:111111111111:cluster/cluster1"
      "labels" : ["app", "chart", "env"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:222222222222:cluster/cluster1"
      "labels" : ["app", "chart", "owner", "environment"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-1:222222222222:cluster/cluster2"
      "labels" : ["app", "chart", "owner"]
    },
    {
      "cluster_arn" : "arn:aws:eks:us-east-2:222222222222:cluster/cluster2"
      "labels" : ["app", "chart", "owner"]
    }
  ]

  description = "A map of clusters and their K8s labels that you wish to include in the dataset"

  # Use-cases for the below input validation:
  # The "cluster_arn" input is empty ("")
  # The "cluster_arn" input has some unstructured string ("test")
  # The "cluster_arn" input has less than 6 fields ("arn:aws:eks")
  # The "cluster_arn" input has less than 6 fields, but is missing the "/" before the resource ID
  # "cluster_arn" : "arn:aws:eks:us-east-1:111111111111:cluster"
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if length(split(":", cluster_arn)) == 6 && length(split("/", cluster_arn)) == 2]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, contains an invalid ARN"
  }

  # Example of an invalid input for the below validation: arn:aaa:eks:us-east-1:111111111111:cluster/cluster1
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if contains(["aws", "aws-cn", "aws-us-gov"], element(split(":", cluster_arn), 1))]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, includes an invalid partition field. The ARN partition field should be one of 'aws', 'aws-cn' or 'aws-us-gov'"
  }

  # Example of an invalid input for the below validation: arn:aws:s3:us-east-1:111111111111:cluster/cluster1
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if element(split(":", cluster_arn), 2) == "eks"]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, includes an invalid service field. The ARN service field should be 'eks'"
  }

  # Example of an invalid input for the below validation: arn:aws:eks::111111111111:cluster/cluster1
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if element(split(":", cluster_arn), 3) != ""]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, is missing a region-code. The ARN of an EKS cluster must include a region-code"
  }

  # Example of an invalid input for the below validation: arn:aws:eks:us-east-1::cluster/cluster1
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if element(split(":", cluster_arn), 4) != ""]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, is missing an account ID. The ARN of an EKS cluster must include an account ID"
  }

#  # Example of an invalid input for the below validation: arn:aws:s3:us-east-1:aaa:cluster/cluster1
#  validation {
#    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if parseint(element(split(":", cluster_arn), 4), 10) == element(split(":", cluster_arn), 4)]) == length(var.clusters_labels)
#    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, includes an account ID which is not a number. The AWS account ID must be a number"
#  }

  # Example of an invalid input for the below validation: arn:aws:s3:us-east-1:11111111111:cluster/cluster1
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if length(element(split(":", cluster_arn), 4)) == 12]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, includes an account ID with invalid length. The AWS account ID must be a 12-digit number"
  }

  # Example of an invalid input for the below validation: arn:aws:s3:us-east-1:111111111111:bucket/cluster1
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if element(split("/", element(split(":", cluster_arn), 5)), 0) == "cluster"]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, includes an invalid resource type. The ARN resource type field should be 'cluster'"
  }

  # Example of an invalid input for the below validation: arn:aws:s3:us-east-1:111111111111:cluster/
  validation {
    condition = length([for cluster_arn in var.clusters_labels.*.cluster_arn : cluster_arn if element(split("/", cluster_arn), 1) != ""]) == length(var.clusters_labels)
    error_message = "One of the 'cluster_arn' inputs in the 'clusters_labels' list, is missing a resource ID. The ARN of an EKS cluster must include a resource ID"
  }
}

variable "aws_shared_config_files" {
  type        = list(string)
  default     = ["~/.aws/config"]
  description = "Paths to the AWS shared config files"

  # Use-cases for the below input validation:
  # The "aws_shared_config_files" has an empty list: []
  # The "aws_shared_config_files" has a single empty item: [""]
  validation {
    condition = length(compact(var.aws_shared_config_files)) > 0
    error_message = "The 'aws_shared_config_files' input is empty. It must contain at least one AWS shared config file"
  }
}

variable "aws_shared_credentials_files" {
  type        = list(string)
  default     = ["~/.aws/credentials"]
  description = "Paths to the AWS shared credentials files"

  # Use-cases for the below input validation:
  # The "aws_shared_credentials_files" has an empty list: []
  # The "aws_shared_credentials_files" has a single empty item: [""]
  validation {
    condition = length(compact(var.aws_shared_credentials_files)) > 0
    error_message = "The 'aws_shared_credentials_files' input is empty. It must contain at least one AWS shared credentials file"
  }
}

variable "granularity" {
  type        = string
  default     = "hourly"
  description = "The time granularity of the data that is returned from the Kubecost Allocation API"

  validation {
    condition = contains(["hourly", "daily"], var.granularity)
    error_message = "The 'granularity' input includes an invalid value. It should be one of 'hourly' or 'daily'"
  }
}