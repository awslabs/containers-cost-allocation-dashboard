# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

variable "glue_database_name" {
  description = <<-EOF
    (Optional) The AWS Glue database name.
               Possible values: A valid AWS Glue database name.
               Meant to only take a reference to the "glue_database_name" output from the pipeline module.
               Must be only "module.pipeline.glue_database_name" (without the double quotes).
  EOF

  type = string

  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.glue_database_name))
    error_message = "The 'glue_database_name' variable contains an invalid AWS Glue Database name"
  }
}

variable "glue_view_name" {
  description = <<-EOF
    (Required) The AWS Glue table name for the Athena view.
               Possible values: A valid AWS Glue table name.
               Meant to only take a reference to the "glue_view_name" output from the pipeline module.
               Must be only "module.pipeline.glue_view_name" (without the double quotes).
  EOF

  type = string

  validation {
    condition     = can(regex("^[a-z0-9_]{1,255}$", var.glue_view_name))
    error_message = "The 'glue_view_name' variable contains an invalid AWS Glue Table name"
  }
}

variable "athena_workgroup_configuration" {
  description = <<-EOF
    (Optional) An object representing the configuration the Athena Workgroup.
               Used either to create a new Athena Workgroup, or reference an existing Athena Workgroup.
               This object has the following fields:

               (Optional) create: Dictates whether to create a custom Athena Workgroup.
                                  Possible values: true or false
                                  Default value: true

               (Optional) name: If "create" is "true", used to define the created Athena Workgroup name, and to reference it in the QuickSight Data Source.
                                If "create" is "false", used only for referencing the Workgroup in the QuickSight Data Source.
                                Possible values: A valid Athena Workgroup name.
                                Default value: "kubecost"

               (Required conditionally) query_results_location_bucket_name: Required only when "create" is "true".
                                                                            In this case, used to set the Athena Workgroup query results location.
                                                                            If "create" is "false", this field is ignored.
                                                                            Possible values: A valid S3 bucket name.
                                                                            Default value: An empty string ("").
  EOF

  type = object({
    create                             = optional(bool, true)
    name                               = optional(string, "kubecost")
    query_results_location_bucket_name = optional(string, "")
  })

  default = {
    create                             = true
    name                               = "kubecost"
    query_results_location_bucket_name = ""
  }

  validation {
    condition = (
      (
        var.athena_workgroup_configuration.create &&
        can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.athena_workgroup_configuration.query_results_location_bucket_name)) &&
        !startswith(var.athena_workgroup_configuration.query_results_location_bucket_name, "xn--") &&
        !endswith(var.athena_workgroup_configuration.query_results_location_bucket_name, "-s3alias") &&
        can(regex("^[A-Za-z0-9_.-]{1,128}$", var.athena_workgroup_configuration.name))
      )
      ||
      (
        !var.athena_workgroup_configuration.create &&
        can(regex("^[A-Za-z0-9_.-]{1,128}$", var.athena_workgroup_configuration.name))
      )
    )
    error_message = <<-EOF
      The 'athena_workgroup_configuration' variable must have one of the following combinations:
      1. When the 'create' field is 'true', the 'name' field must have a valid Athena Workgroup name, and the 'query_results_location_bucket_name' field must have a valid S3 bucket name
      2. When the 'create' field is 'false', the 'name' field must have a valid Athena Workgroup name, and 'query_results_location_bucket_name' is ignored (so it can have any value)
    EOF
  }
}

variable "qs_common_users" {
  description = <<-EOF
    (Optional) A list of QuickSight users and and their permissions for each QuickSight asset created by this module.
               Add users here if you want them to have access to all QuickSight assets created by this module.
               Each item in the list is an object with the following fields:

              (Required) username: The QuickSight username.
                                   Possible values: A valid QuickSight username.

              (Optional) data_source_permissions: The user's permissions for the QuickSight data source asset.
                                                  Possible values: "Owner" or "Viewer".
                                                  Default value: "Owner".

              (Optional) data_set_permissions: The user's permissions for the dataset asset.
                                               Possible values: "Owner" or "Viewer".
                                               Default value: "Owner".
  EOF

  type = list(object({
    username                = string
    data_source_permissions = optional(string, "Owner")
    data_set_permissions    = optional(string, "Owner")
  }))

  default = []

  validation {
    condition = (
      length([
        for user in var.qs_common_users : user
        if contains(["Owner", "Viewer"], user.data_source_permissions) && contains(["Owner", "Viewer"], user.data_set_permissions)
      ]) == length(var.qs_common_users)
    )
    error_message = "One of the users in the 'qs_common_users' has invalid permissions (must be 'Owner' or 'Viewer')"
  }

}

variable "qs_data_source_settings" {
  description = <<-EOF
    (Optional) An object representing the configuration the QuickSight data source.
               This object has the following fields:

               (Optional) name: The name of the QuickSight data source.
                                Possible values: A valid QuickSight data source name.
                                Default value: "cca_kubecost"

               (Optional) users: A list of QuickSight users and and their permissions.
                                 Users in this list take precedence over users in "qs_common_users" list, if they appear in both.
                                 Each item in the list is an object with the following fields:

                                (Required) username: The QuickSight username.
                                                     Possible values: A valid QuickSight username.

                                (Optional) permissions: The user's permissions for the QuickSight data source asset.
                                                        Possible values: "Owner" or "Viewer".
                                                        Default value: "Owner"
  EOF

  type = object({
    name = optional(string, "cca_kubecost")
    users = optional(list(object({
      username    = string
      permissions = optional(string, "Owner")
    })), [])
  })

  default = {
    name  = "cca_kubecost"
    users = []
  }

  validation {
    condition = (
      length(var.qs_data_source_settings.name) >= 1 &&
      length(var.qs_data_source_settings.name) <= 128
    )
    error_message = "The 'name' field in the 'qs_data_source_settings' variable must contain a string in the length between 1 and 128 characters"
  }
  validation {
    condition = (
      length([
        for user in var.qs_data_source_settings.users : user
        if contains(["Owner", "Viewer"], user.permissions) && contains(["Owner", "Viewer"], user.permissions)
      ]) == length(var.qs_data_source_settings.users)
    )
    error_message = "One of the users in the 'users' field of the 'qs_data_source_settings' variable has invalid permissions (must be 'Owner' or 'Viewer')"
  }

}

variable "qs_data_set_settings" {
  description = <<-EOF
    (Optional) An object representing the configuration the QuickSight dataset.
               This object has the following fields:

               (Optional) users: A list of QuickSight users and and their permissions.
                                 Users in this list take precedence over users in "qs_common_users" list, if they appear in both.
                                 Each item in the list is an object with the following fields:

                                (Required) username: The QuickSight username.
                                                     Possible values: A valid QuickSight username.

                                (Optional) permissions: The user's permissions for the QuickSight dataset asset.
                                                        Possible values: "Owner" or "Viewer".
                                                        Default value: "Owner"
  EOF
  type = object({
    dataset_refresh_schedule = optional(string, "05:00")
    timezone                 = optional(string, "")
    users = optional(list(object({
      username    = string
      permissions = optional(string, "Owner")
    })), [])
  })

  default = {
    dataset_refresh_schedule = "05:00"
    timezone                 = ""
    users                    = []
  }

  validation {
    condition     = can(regex("([0-1]?[0-9]|2[0-3]):[0-5][0-9]$", var.qs_data_set_settings.dataset_refresh_schedule))
    error_message = "The 'dataset_refresh_schedule' field in the 'qs_data_set_settings' must be in format of 'HH:MM'"
  }
  validation {
    condition     = contains(split("\n", file("../modules/quicksight/timezones.txt")), var.qs_data_set_settings.timezone)
    error_message = "The 'timezone' field in the 'qs_data_set_settings' contains an invalid value. It must be one of the timezones listed in 'timezones.txt' file"
  }
  validation {
    condition = (
      length([
        for user in var.qs_data_set_settings.users : user
        if contains(["Owner", "Viewer"], user.permissions) && contains(["Owner", "Viewer"], user.permissions)
      ]) == length(var.qs_data_set_settings.users)
    )
    error_message = "One of the users in the 'users' field of the 'qs_data_set_settings' variable has invalid permissions (must be 'Owner' or 'Viewer')"
  }

}