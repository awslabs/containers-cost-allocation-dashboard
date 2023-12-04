# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

locals {
  bucket_name = element(split(":::", var.bucket_arn), 1)

  # The below local variable is used to define the static columns of the schema
  # It maps each column to hive, presto and QuickSight dataset data types
  # The hive type is used in AWS Glue table, the prews
  static_columns = [
    {
      name             = "name"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "window.start"
      qs_data_set_type = "DATETIME"
      hive_type        = "timestamp"
      persto_type      = "timestamp"
    },
    {
      name             = "window.end"
      qs_data_set_type = "DATETIME"
      hive_type        = "timestamp"
      persto_type      = "timestamp"
    },
    {
      name             = "minutes"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpucores"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpucorerequestaverage"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpucoreusageaverage"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpucorehours"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpucost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpucostadjustment"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "cpuefficiency"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "gpucount"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "gpuhours"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "gpucost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "gpucostadjustment"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networktransferbytes"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networkreceivebytes"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networkcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networkcrosszonecost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networkcrossregioncost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networkinternetcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "networkcostadjustment"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "loadbalancercost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "loadbalancercostadjustment"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "pvbytes"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "pvbytehours"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "pvcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "pvcostadjustment"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "rambytes"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "rambyterequestaverage"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "rambyteusageaverage"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "rambytehours"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "ramcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "ramcostadjustment"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "ramefficiency"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "sharedcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "externalcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "totalcost"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "totalefficiency"
      qs_data_set_type = "DECIMAL"
      hive_type        = "double"
      persto_type      = "double"
    },
    {
      name             = "properties.provider"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.region"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.cluster"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.clusterid"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.eksclustername"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.container"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.namespace"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.pod"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_instance_type"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_availability_zone"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_capacity_type"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_architecture"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_os"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_nodegroup"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.node_nodegroup_image"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.controller"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.controllerkind"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "properties.providerid"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    }
  ]

  # The below local is used to define the partition keys of the schema that is used in both the AWS Glue Table and the QuickSight Dataset
  partition_keys = [
    {
      name             = "account_id"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "region"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "year"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    },
    {
      name             = "month"
      qs_data_set_type = "STRING"
      hive_type        = "string"
      persto_type      = "varchar"
    }
  ]
}