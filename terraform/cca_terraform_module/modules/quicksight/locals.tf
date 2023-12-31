locals {

  #                                                            #
  # Building users lists for each asset (data source, dataset) #
  #                                                            #

  # In "variables.tf" of this module, we provide variables
  # Building a distinct list of QS users from the common QS users and users of specific assets (data source, dataset)
  # A few notes:
  # 1/ The current QS user that applies the module will be excluded.
  #    That's because this user will always be given "Owner" permissions (it's defined later in this module)
  # 2/ In case of duplicate users in the asset-specific variables ("qs_data_source_settings" and "qs_data_set_settings" variables) and "qs_common_users" variable:
  #    Users in the respective asset-specific variable take precedences.
  #    This means the the permissions of this user from the asset-specific variable will be used.
  combined_qs_data_source_users = [for user in flatten([[for user in var.qs_common_users : { username : user.username, permissions : user.data_source_permissions }], var.qs_data_source_settings.users]) : user if user.username != data.aws_quicksight_user.qs_current_user.user_name]
  distinct_qs_data_source_users = values(zipmap(local.combined_qs_data_source_users.*.username, local.combined_qs_data_source_users))

  combined_qs_data_set_users = [for user in flatten([[for user in var.qs_common_users : { username : user.username, permissions : user.data_set_permissions }], var.qs_data_set_settings.users]) : user if user.username != data.aws_quicksight_user.qs_current_user.user_name]
  distinct_qs_data_set_users = values(zipmap(local.combined_qs_data_set_users.*.username, local.combined_qs_data_set_users))

  qs_data_set_custom_columns = [
    "region_code"
  ]

  qs_data_set_logical_table_map_projected_columns = concat(
    module.common_locals.static_columns.*.name,
    formatlist("properties.labels.%s", distinct(var.k8s_labels)),
    formatlist("properties.annotations.%s", distinct(var.k8s_annotations)),
    module.common_locals.partition_keys.*.name,
    local.qs_data_set_custom_columns
  )

  region_to_timezone_mapping = {
    "us-east-2" : "America/New_York",
    "us-east-1" : "America/New_York",
    "us-west-1" : "America/Los_Angeles",
    "us-west-2" : "America/Los_Angeles",
    "af-south-1" : "Africa/Blantyre",
    "ap-east-1" : "Asia/Hong_Kong",
    "ap-south-2" : "Asia/Kolkata",
    "ap-southeast-3" : "Asia/Jakarta",
    "ap-southeast-4" : "Australia/Melbourne",
    "ap-south-1" : "Asia/Kolkata",
    "ap-northeast-3" : "Asia/Tokyo",
    "ap-northeast-2" : "Asia/Seoul",
    "ap-southeast-1" : "Asia/Singapore",
    "ap-southeast-2" : "Australia/Sydney",
    "ap-northeast-1" : "Asia/Tokyo",
    "ca-central-1" : "America/Toronto",
    "eu-central-1" : "Europe/Berlin",
    "eu-west-1" : "Europe/Dublin",
    "eu-west-2" : "Europe/London",
    "eu-south-1" : "Europe/Rome",
    "eu-west-3" : "Europe/Paris",
    "eu-south-2" : "Europe/Madrid",
    "eu-north-1" : "Europe/Stockholm",
    "eu-central-2" : "Europe/Zurich",
    "il-central-1" : "Asia/Jerusalem",
    "me-south-1" : "Asia/Riyadh",
    "me-central-1" : "Asia/Dubai",
    "sa-east-1" : "America/Sao_Paulo",
    "us-gov-east-1" : "US/Eastern",
    "us-gov-west-1" : "US/Pacific",
  }

}