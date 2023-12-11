# Copyright 2023 Amazon.com and its affiliates; all rights reserved. This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

dashboards:
  CONTAINERS COST ALLOCATION (CCA):
    dependsOn:
      datasets:
      - ${data_set_name}
    name: Containers Cost Allocation (CCA)
    dashboardId: containers-cost-allocation-cca
    category: Custom
    templateId: containers-cost-allocation-cca
    sourceAccountId: '829389350341'
    region: us-east-1
datasets:
  ${data_set_name}:
    data:
      DataSetId: ${data_set_id}
      Name: ${data_set_name}
views: {}
