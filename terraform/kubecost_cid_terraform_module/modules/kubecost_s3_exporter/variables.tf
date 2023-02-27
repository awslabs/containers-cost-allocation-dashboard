# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "cluster_arn" {
  type = string
  description = "The EKS cluster ARN in which the Kubecost S3 Exporter pod will be deployed"
}

variable "cluster_context" {
  type = string
  description = "The EKS cluster context name from the kubeconfig file"
}

variable "cluster_oidc_provider_arn" {
  type = string
  description = "The IAM OIDC Provider ARN for the EKS cluster"
}

variable "aws_region" {
  type = string
  description = "The region where the EKS cluster resides"
}

variable "aws_profile" {
  type = string
  description = "The AWS profile to use for configuration and credentials to access the EKS cluster"
}

variable "kubecost_s3_exporter_container_image" {
  type = string
  description = "The Kubecost S3 Exporter container image"
}

variable "kubecost_s3_exporter_container_image_pull_policy" {
  type = string
  default = "Always"
  description = "The image pull policy that'll be used by the Kubecost S3 Exporter pod"
}

variable "kubecost_s3_exporter_cronjob_schedule" {
  type = string
  default = "0 0 * * *"
  description = "The schedule of the Kubecost S3 Exporter CronJob"
}

variable "kubecost_api_endpoint" {
  type = string
  default = "http://kubecost-cost-analyzer.kubecost:9090"
  description = "The Kubecost API endpoint in format of 'http://<name_or_ip>:<port>'"
}

variable "k8s_config_path" {
  type = string
  default = "~/.kube/config"
  description = "The K8s config file to be used by Helm"
}

variable "namespace" {
  type = string
  default = "kubecost-s3-exporter"
  description = "The namespace in which the Kubecost S3 Exporter pod and service account will be created"
}

variable "create_namespace" {
  type = bool
  default = true
  description = "Dictates whether to create the namespace as part of the Helm Chart deployment"
}

variable "service_account" {
  type = string
  default = "kubecost-s3-exporter"
  description = "The service account for the Kubecost S3 Exporter pod"
}

variable "create_service_account" {
  type = bool
  default = true
  description = "Dictates whether to create the service account as part of the Helm Chart deployment"
}