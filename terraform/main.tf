resource "aws_s3_bucket" "kubecost_cid_bucket" {
  bucket = local.bucket
}

resource "aws_s3_bucket_public_access_block" "s3_block_all_public_access" {
  bucket = aws_s3_bucket.kubecost_cid_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_glue_catalog_database" "kubecost_cid_glue_db" {
  name = local.name
}

resource "aws_glue_catalog_table" "kubecost_cid_glue_table" {
  name          = local.name
  database_name = aws_glue_catalog_database.kubecost_cid_glue_db.name
  parameters    = {
    "classification"                   = "csv"
    "delimiter"                        = ","
    "skip.header.line.count"           = "1"
  }

  table_type = "EXTERNAL_TABLE"

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.kubecost_cid_bucket.bucket}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    parameters                = {
      "classification"                   = "csv"
      "delimiter"                        = ","
      "skip.header.line.count"           = "1"
    }

    ser_de_info {
      name                  = local.name
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters            = {
        "field.delim"                        = ","
      }
    }

    columns {
      name = "name"
      type = "string"
    }

    columns {
      name = "window.start"
      type = "timestamp"
    }

    columns {
      name = "window.end"
      type = "timestamp"
    }

    columns {
      name = "minutes"
      type = "double"
    }

    columns {
      name = "cpucores"
      type = "double"
    }
    columns {
      name = "cpucorerequestaverage"
      type = "double"
    }
    columns {
      name = "cpucoreusageaverage"
      type = "double"
    }
    columns {
      name = "cpucorehours"
      type = "double"
    }
    columns {
      name = "cpucost"
      type = "double"
    }
    columns {
      name = "cpucostadjustment"
      type = "double"
    }
    columns {
      name = "cpuefficiency"
      type = "double"
    }
    columns {
      name = "gpucount"
      type = "double"
    }
    columns {
      name = "gpuhours"
      type = "double"
    }
    columns {
      name = "gpucost"
      type = "double"
    }
    columns {
      name = "gpucostadjustment"
      type = "double"
    }
    columns {
      name = "networktransferbytes"
      type = "double"
    }
    columns {
      name = "networkreceivebytes"
      type = "double"
    }
    columns {
      name = "networkcost"
      type = "double"
    }
    columns {
      name = "networkcostadjustment"
      type = "double"
    }
    columns {
      name = "loadbalancercost"
      type = "double"
    }
    columns {
      name = "loadbalancercostadjustment"
      type = "double"
    }
    columns {
      name = "pvbytes"
      type = "double"
    }
    columns {
      name = "pvbytehours"
      type = "double"
    }
    columns {
      name = "pvcost"
      type = "double"
    }
    columns {
      name = "pvcostadjustment"
      type = "double"
    }
    columns {
      name = "rambytes"
      type = "double"
    }
    columns {
      name = "rambyterequestaverage"
      type = "double"
    }
    columns {
      name = "rambyteusageaverage"
      type = "double"
    }
    columns {
      name = "rambytehours"
      type = "double"
    }
    columns {
      name = "ramcost"
      type = "double"
    }
    columns {
      name = "ramcostadjustment"
      type = "double"
    }
    columns {
      name = "ramefficiency"
      type = "double"
    }
    columns {
      name = "sharedcost"
      type = "double"
    }
    columns {
      name = "externalcost"
      type = "double"
    }
    columns {
      name = "totalcost"
      type = "double"
    }
    columns {
      name = "totalefficiency"
      type = "double"
    }
    columns {
      name = "rawallocationonly"
      type = "double"
    }
    columns {
      name = "properties.cluster"
      type = "string"
    }
    columns {
      name = "properties.container"
      type = "string"
    }
    columns {
      name = "properties.namespace"
      type = "string"
    }
    columns {
      name = "properties.pod"
      type = "string"
    }
    columns {
      name = "properties.node"
      type = "string"
    }
    columns {
      name = "properties.controller"
      type = "string"
    }
    columns {
      name = "properties.controllerkind"
      type = "string"
    }
    columns {
      name = "properties.providerid"
      type = "string"
    }
  }
}
