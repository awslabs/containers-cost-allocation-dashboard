# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

locals {
  # The below local is used to define the static columns of the schema that is used in both the AWS Glue Table and the QuickSight Dataset
  static_columns = [
    {
      name             = "name"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "window.start"
      qs_data_set_type = "DATETIME"
      glue_table_type  = "timestamp"
    },
    {
      name             = "window.end"
      qs_data_set_type = "DATETIME"
      glue_table_type  = "timestamp"
    },
    {
      name             = "minutes"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpucores"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpucorerequestaverage"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpucoreusageaverage"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpucorehours"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpucost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpucostadjustment"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "cpuefficiency"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "gpucount"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "gpuhours"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "gpucost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "gpucostadjustment"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networktransferbytes"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networkreceivebytes"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networkcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networkcrosszonecost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networkcrossregioncost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networkinternetcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "networkcostadjustment"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "loadbalancercost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "loadbalancercostadjustment"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "pvbytes"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "pvbytehours"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "pvcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "pvcostadjustment"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "rambytes"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "rambyterequestaverage"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "rambyteusageaverage"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "rambytehours"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "ramcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "ramcostadjustment"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "ramefficiency"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "sharedcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "externalcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "totalcost"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "totalefficiency"
      qs_data_set_type = "DECIMAL"
      glue_table_type  = "double"
    },
    {
      name             = "properties.provider"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.region"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.cluster"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.clusterid"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.eksclustername"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.container"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.namespace"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.pod"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_instance_type"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_availability_zone"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_capacity_type"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_architecture"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_os"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_nodegroup"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.node_nodegroup_image"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.controller"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.controllerkind"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "properties.providerid"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    }
  ]

  # The below local is used to define the partition keys of the schema that is used in both the AWS Glue Table and the QuickSight Dataset
  partition_keys = [
    {
      name             = "account_id"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "region"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "year"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    },
    {
      name             = "month"
      qs_data_set_type = "STRING"
      glue_table_type  = "string"
    }
  ]
}