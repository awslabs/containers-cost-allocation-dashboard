# Copyright 2022 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

dashboards:
  EKS INSIGHTS:
    name: EKS Insights
    templateId: eks_insights
    sourceAccountId: '829389350341'
    region: us-east-1
    dashboardId: eks_insights
    dependsOn:
      datasets:
      - eks_insights
datasets:
  eks_insights:
    Data:
      DataSetId: e88edf48-f2cd-4c23-b6a4-e2b3034e2c41
      Name: eks_insights
      PhysicalTableMap:
        06f7b96e-4cd6-4d7f-83a8-e8b9302da3f4:
          RelationalTable:
            DataSourceArn: ${athena_datasource_arn}
            Catalog: AwsDataCatalog
            Schema: ${athena_database_name}
            Name: kubecost_table
            InputColumns:
            - Name: name
              Type: STRING
            - Name: window.start
              Type: DATETIME
            - Name: window.end
              Type: DATETIME
            - Name: minutes
              Type: DECIMAL
            - Name: cpucores
              Type: DECIMAL
            - Name: cpucorerequestaverage
              Type: DECIMAL
            - Name: cpucoreusageaverage
              Type: DECIMAL
            - Name: cpucorehours
              Type: DECIMAL
            - Name: cpucost
              Type: DECIMAL
            - Name: cpucostadjustment
              Type: DECIMAL
            - Name: cpuefficiency
              Type: DECIMAL
            - Name: gpucount
              Type: DECIMAL
            - Name: gpuhours
              Type: DECIMAL
            - Name: gpucost
              Type: DECIMAL
            - Name: gpucostadjustment
              Type: DECIMAL
            - Name: networktransferbytes
              Type: DECIMAL
            - Name: networkreceivebytes
              Type: DECIMAL
            - Name: networkcost
              Type: DECIMAL
            - Name: networkcostadjustment
              Type: DECIMAL
            - Name: loadbalancercost
              Type: DECIMAL
            - Name: loadbalancercostadjustment
              Type: DECIMAL
            - Name: pvbytes
              Type: DECIMAL
            - Name: pvbytehours
              Type: DECIMAL
            - Name: pvcost
              Type: DECIMAL
            - Name: pvcostadjustment
              Type: DECIMAL
            - Name: rambytes
              Type: DECIMAL
            - Name: rambyterequestaverage
              Type: DECIMAL
            - Name: rambyteusageaverage
              Type: DECIMAL
            - Name: rambytehours
              Type: DECIMAL
            - Name: ramcost
              Type: DECIMAL
            - Name: ramcostadjustment
              Type: DECIMAL
            - Name: ramefficiency
              Type: DECIMAL
            - Name: sharedcost
              Type: DECIMAL
            - Name: externalcost
              Type: DECIMAL
            - Name: totalcost
              Type: DECIMAL
            - Name: totalefficiency
              Type: DECIMAL
            - Name: properties.provider
              Type: STRING
            - Name: properties.region
              Type: STRING
            - Name: properties.cluster
              Type: STRING
            - Name: properties.clusterid
              Type: STRING
            - Name: properties.eksclustername
              Type: STRING
            - Name: properties.container
              Type: STRING
            - Name: properties.namespace
              Type: STRING
            - Name: properties.pod
              Type: STRING
            - Name: properties.node
              Type: STRING
            - Name: properties.node_instance_type
              Type: STRING
            - Name: properties.node_availability_zone
              Type: STRING
            - Name: properties.node_capacity_type
              Type: STRING
            - Name: properties.node_architecture
              Type: STRING
            - Name: properties.node_os
              Type: STRING
            - Name: properties.node_nodegroup
              Type: STRING
            - Name: properties.node_nodegroup_image
              Type: STRING
            - Name: properties.controller
              Type: STRING
            - Name: properties.controllerkind
              Type: STRING
            - Name: properties.providerid
              Type: STRING
%{ for label in labels ~}
            - Name: properties.labels.${label}
              Type: STRING
%{ endfor ~}
            - Name: account_id
              Type: STRING
            - Name: region
              Type: STRING
            - Name: year
              Type: STRING
            - Name: month
              Type: STRING
      LogicalTableMap:
        06f7b96e-4cd6-4d7f-83a8-e8b9302da3f4:
          Alias: kubecost_table
          DataTransforms:
          - CreateColumnsOperation:
              Columns:
              - ColumnName: region_code
                ColumnId: 44b43fa2-9916-4d2a-94d1-a829f131077b
                Expression: "ifelse(\n    isNotNull({properties.region}), {properties.region},\n\
                  \    region\n)"
          - ProjectOperation:
              ProjectedColumns:
              - name
              - window.start
              - window.end
              - minutes
              - cpucores
              - cpucorerequestaverage
              - cpucoreusageaverage
              - cpucorehours
              - cpucost
              - cpucostadjustment
              - cpuefficiency
              - gpucount
              - gpuhours
              - gpucost
              - gpucostadjustment
              - networktransferbytes
              - networkreceivebytes
              - networkcost
              - networkcostadjustment
              - loadbalancercost
              - loadbalancercostadjustment
              - pvbytes
              - pvbytehours
              - pvcost
              - pvcostadjustment
              - rambytes
              - rambyterequestaverage
              - rambyteusageaverage
              - rambytehours
              - ramcost
              - ramcostadjustment
              - ramefficiency
              - sharedcost
              - externalcost
              - totalcost
              - totalefficiency
              - properties.provider
              - properties.region
              - properties.cluster
              - properties.clusterid
              - properties.eksclustername
              - properties.container
              - properties.namespace
              - properties.pod
              - properties.node
              - properties.node_instance_type
              - properties.node_availability_zone
              - properties.node_capacity_type
              - properties.node_architecture
              - properties.node_os
              - properties.node_nodegroup
              - properties.node_nodegroup_image
              - properties.controller
              - properties.controllerkind
              - properties.providerid
%{ for label in labels ~}
              - properties.labels.${label}
%{ endfor ~}
              - account_id
              - region
              - year
              - month
              - region_code
          Source:
            PhysicalTableId: 06f7b96e-4cd6-4d7f-83a8-e8b9302da3f4
      ImportMode: SPICE
views: {}
