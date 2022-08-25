CREATE EXTERNAL TABLE `kubecost`(
  `podname` string, 
  `start` string, 
  `end` string, 
  `minutes` double, 
  `cpu_cores` double, 
  `cpu_core_request_average` double, 
  `cpu_core_usage_average` double, 
  `cpu_core_hours` double, 
  `cpu_cost` double, 
  `cpu_cost_adjustment` double, 
  `cpu_efficiency` double, 
  `gpu_count` double, 
  `gpu_hours` double, 
  `gpu_cost` double, 
  `gpu_cost_adjustment` double, 
  `network_transfer_bytes` double, 
  `network_receive_bytes` double, 
  `network_cost` double, 
  `network_cost_adjustment` double, 
  `load_balancer_cost` double, 
  `load_balancer_cost_adjustment` double, 
  `pv_bytes` double, 
  `pv_byte_hours` double, 
  `pv_cost` double, 
  `pvs` double, 
  `pv_cost_adjustment` double, 
  `ram_bytes` double, 
  `ram_byte_request_average` double, 
  `ram_byte_usage_average` double, 
  `ram_byte_hours` double, 
  `ram_cost` double, 
  `ram_cost_adjustment` double, 
  `ram_efficiency` double, 
  `shared_cost` double, 
  `external_cost` double, 
  `total_cost` double, 
  `total_efficiency` double, 
  `raw_allocation_only` double, 
  `properties_cluster` string, 
  `properties_container` string, 
  `properties_namespace` string, 
  `properties_pod` string, 
  `properties_node` string, 
  `properties_controller` string, 
  `properties_controller_kind` string, 
  `properties_provider_id` string)
PARTITIONED BY ( 
  `year` string, 
  `month` string, 
  `day` string)
ROW FORMAT DELIMITED 
  FIELDS TERMINATED BY ',' 
STORED AS INPUTFORMAT 
  'org.apache.hadoop.mapred.TextInputFormat' 
OUTPUTFORMAT 
  'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION
  's3://nialt-kubecost-csv/'
TBLPROPERTIES (
  'has_encrypted_data'='false', 
  'skip.header.line.count'='1', 
  'transient_lastDdlTime'='1657591900')
