# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

module "common_locals" {
  source = "../common_locals"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}

data "aws_region" "quicksight_region" {}
data "aws_caller_identity" "quicksight_caller_identity" {}

data "aws_quicksight_user" "qs_current_user" {
  user_name = element(split(":assumed-role/", data.aws_caller_identity.quicksight_caller_identity.arn), 1)
}

data "aws_quicksight_user" "qs_data_source_users" {
  count = length(local.distinct_qs_data_source_users)

  user_name = local.distinct_qs_data_source_users[count.index].username
}

data "aws_quicksight_user" "qs_data_set_users" {
  count = length(local.distinct_qs_data_set_users)

  user_name = local.distinct_qs_data_set_users[count.index].username
}

# This data source is used conditionally, only if the "create" field in the "custom_athena_workgroup" variable is "true"
data "aws_kms_key" "s3_kms" {
  count = var.athena_workgroup_configuration.create ? 1 : 0

  key_id = "alias/aws/s3"
}

# This resource is created conditionally, only if the "create" field in the "custom_athena_workgroup" variable is "true"
resource "aws_athena_workgroup" "kubecost_athena_workgroup" {
  count = var.athena_workgroup_configuration.create ? 1 : 0

  name          = var.athena_workgroup_configuration.name
  force_destroy = true

  configuration {
    result_configuration {
      output_location       = "s3://${var.athena_workgroup_configuration.query_results_location_bucket_name}/"
      expected_bucket_owner = data.aws_caller_identity.quicksight_caller_identity.account_id
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = data.aws_kms_key.s3_kms[count.index].arn
      }
    }
  }
}

resource "random_uuid" "qs_data_source_cca_uuid" {}

resource "aws_quicksight_data_source" "cca" {
  data_source_id = random_uuid.qs_data_source_cca_uuid.id
  name           = var.qs_data_source_settings.name
  type           = "ATHENA"

  parameters {
    athena {
      work_group = var.athena_workgroup_configuration.create ? aws_athena_workgroup.kubecost_athena_workgroup[0].name : var.athena_workgroup_configuration.name
    }
  }

  ssl_properties {
    disable_ssl = false
  }

  # Adding the user that applies the module, as "Owner"
  permission {
    actions = [
      "quicksight:DeleteDataSource",
      "quicksight:DescribeDataSource",
      "quicksight:DescribeDataSourcePermissions",
      "quicksight:PassDataSource",
      "quicksight:UpdateDataSource",
      "quicksight:UpdateDataSourcePermissions"
    ]
    principal = data.aws_quicksight_user.qs_current_user.arn
  }

  # Adding other users that were given as input, with their respective permissions
  dynamic "permission" {
    for_each = data.aws_quicksight_user.qs_data_source_users
    content {
      actions = lookup(element(local.distinct_qs_data_source_users, index(local.distinct_qs_data_source_users.*.username, permission.value.user_name)), "permissions", "Owner") == "Owner" ? [
        "quicksight:DeleteDataSource",
        "quicksight:DescribeDataSource",
        "quicksight:DescribeDataSourcePermissions",
        "quicksight:PassDataSource",
        "quicksight:UpdateDataSource",
        "quicksight:UpdateDataSourcePermissions"
        ] : [
        "quicksight:DescribeDataSource",
        "quicksight:DescribeDataSourcePermissions",
        "quicksight:PassDataSource"
      ]
      principal = data.aws_quicksight_user.qs_data_source_users[permission.key].arn
    }
  }
}

resource "random_uuid" "qs_data_set_cca_uuid" {}
resource "random_uuid" "qs_data_set_cca_physical_and_logical_table_maps_uuid" {}
resource "random_uuid" "qs_data_set_cca_custom_column_region_code_uuid" {}

resource "aws_quicksight_data_set" "cca" {
  data_set_id = random_uuid.qs_data_set_cca_uuid.id
  import_mode = "SPICE"
  name        = "cca_kubecost_view"

  data_set_usage_configuration {
    disable_use_as_direct_query_source = false
    disable_use_as_imported_source     = false
  }

  logical_table_map {
    alias                = var.glue_view_name
    logical_table_map_id = random_uuid.qs_data_set_cca_physical_and_logical_table_maps_uuid.id

    data_transforms {
      create_columns_operation {
        columns {
          column_id   = random_uuid.qs_data_set_cca_custom_column_region_code_uuid.id
          column_name = "region_code"
          expression  = <<-EOT
          ifelse(
              isNotNull({properties.region}), {properties.region},
              region
          )
          EOT
        }
      }
    }
    data_transforms {
      project_operation {
        projected_columns = local.qs_data_set_logical_table_map_projected_columns
      }
    }
    data_transforms {
      tag_column_operation {
        column_name = "region"
        tags {
          column_geographic_role = "STATE"
        }
      }
    }
    data_transforms {
      tag_column_operation {
        column_name = "region_code"
        tags {
          column_geographic_role = "STATE"
        }
      }
    }

    source {
      physical_table_id = random_uuid.qs_data_set_cca_physical_and_logical_table_maps_uuid.id
    }
  }

  # Adding the user that applies the module, as "Owner"
  permissions {
    actions = [
      "quicksight:CancelIngestion",
      "quicksight:CreateIngestion",
      "quicksight:DeleteDataSet",
      "quicksight:DescribeDataSet",
      "quicksight:DescribeDataSetPermissions",
      "quicksight:DescribeIngestion",
      "quicksight:ListIngestions",
      "quicksight:PassDataSet",
      "quicksight:UpdateDataSet",
      "quicksight:UpdateDataSetPermissions",
    ]
    principal = data.aws_quicksight_user.qs_current_user.arn
  }

  # Adding other users that were given as input, with their respective permissions
  dynamic "permissions" {
    for_each = data.aws_quicksight_user.qs_data_set_users
    content {
      actions = lookup(element(local.distinct_qs_data_set_users, index(local.distinct_qs_data_set_users.*.username, permissions.value.user_name)), "permissions", "Owner") == "Owner" ? [
        "quicksight:CancelIngestion",
        "quicksight:CreateIngestion",
        "quicksight:DeleteDataSet",
        "quicksight:DescribeDataSet",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:DescribeIngestion",
        "quicksight:ListIngestions",
        "quicksight:PassDataSet",
        "quicksight:UpdateDataSet",
        "quicksight:UpdateDataSetPermissions",
        ] : [
        "quicksight:DescribeDataSet",
        "quicksight:DescribeDataSetPermissions",
        "quicksight:DescribeIngestion",
        "quicksight:DescribeRefreshSchedule",
        "quicksight:ListIngestions",
        "quicksight:ListRefreshSchedules",
        "quicksight:PassDataSet"
      ]
      principal = data.aws_quicksight_user.qs_data_set_users[permissions.key].arn
    }
  }

  physical_table_map {
    physical_table_map_id = random_uuid.qs_data_set_cca_physical_and_logical_table_maps_uuid.id

    relational_table {
      catalog         = "AwsDataCatalog"
      data_source_arn = aws_quicksight_data_source.cca.arn
      name            = var.glue_view_name
      schema          = var.glue_database_name

      dynamic "input_columns" {
        for_each = [for static_column in module.common_locals.static_columns : static_column]
        content {
          name = input_columns.value.name
          type = input_columns.value.qs_data_set_type
        }
      }
      dynamic "input_columns" {
        for_each = [for k8s_label in distinct(var.k8s_labels) : k8s_label]
        content {
          name = "properties.labels.${input_columns.value}"
          type = "STRING"
        }
      }
      dynamic "input_columns" {
        for_each = [for k8s_annotation in distinct(var.k8s_annotations) : k8s_annotation]
        content {
          name = "properties.annotations.${input_columns.value}"
          type = "STRING"
        }
      }
      dynamic "input_columns" {
        for_each = [for partition_key in module.common_locals.partition_keys : partition_key]
        content {
          name = input_columns.value.name
          type = input_columns.value.qs_data_set_type
        }
      }
    }
  }
}

resource "random_uuid" "qs_data_set_cca_refresh_schedule_uuid" {}
resource "time_offset" "qs_data_set_cca_start_after" {
  offset_minutes = 5
}

resource "aws_quicksight_refresh_schedule" "cca" {
  data_set_id = aws_quicksight_data_set.cca.data_set_id
  schedule_id = random_uuid.qs_data_set_cca_refresh_schedule_uuid.id
  schedule {
    refresh_type = "FULL_REFRESH"
    schedule_frequency {
      interval        = "DAILY"
      timezone        = var.qs_data_set_settings.timezone != "" ? var.qs_data_set_settings.timezone : lookup(local.region_to_timezone_mapping, data.aws_region.quicksight_region.name, "America/New_York")
      time_of_the_day = var.qs_data_set_settings.dataset_refresh_schedule
    }
    start_after_date_time = trimsuffix(time_offset.qs_data_set_cca_start_after.rfc3339, "Z")
  }
}

resource "local_file" "cid_yaml" {
  filename             = "${path.module}/../../../../cid/cca.yaml"
  directory_permission = "0400"
  file_permission      = "0400"
  content = templatefile("${path.module}/../../../../cid/cca.yaml.tpl", {
    data_set_name = aws_quicksight_data_set.cca.name
    data_set_id   = aws_quicksight_data_set.cca.data_set_id
  })
}