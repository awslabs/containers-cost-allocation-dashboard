import requests
import pandas as pd
import datetime
import boto3
import os

cluster_id = os.environ["EKS_CLUSTER_ID"]
bucket_name = os.environ["S3_BUCKET_NAME"]
kubecost_endpoint = os.environ.get("KUBECOST_API_ENDPOINT", "http://kubecost-cost-analyzer.kubecost.svc")

today = datetime.date.today()

start = today - datetime.timedelta(days=2)
end = today - datetime.timedelta(days=1)

window = "{}T00:00:00Z,{}T00:00:00Z".format(start.strftime('%Y-%m-%d'), end.strftime('%Y-%m-%d'))

print("Targeting window {}".format(window))

params = {'window': window, 'aggregate':'pod', 'accumulate': 'true', 'shareIdle': 'false'}

r = requests.get('{}/model/allocation'.format(kubecost_endpoint), params=params)

response = r.json()

df = pd.json_normalize(response["data"][0].values())

columns = [
  'name',
  'window.start',
  'window.end',
  'minutes',
  'cpuCores', 
  'cpuCoreRequestAverage', 
  'cpuCoreUsageAverage', 
  'cpuCoreHours', 
  'cpuCost', 
  'cpuCostAdjustment', 
  'cpuEfficiency', 
  'gpuCount', 
  'gpuHours', 
  'gpuCost', 
  'gpuCostAdjustment', 
  'networkTransferBytes', 
  'networkReceiveBytes', 
  'networkCost', 
  'networkCostAdjustment', 
  'loadBalancerCost', 
  'loadBalancerCostAdjustment', 
  'pvBytes', 
  'pvByteHours', 
  'pvCost', 
  'pvs', 
  'pvCostAdjustment', 
  'ramBytes', 
  'ramByteRequestAverage', 
  'ramByteUsageAverage', 
  'ramByteHours', 
  'ramCost', 
  'ramCostAdjustment', 
  'ramEfficiency', 
  'sharedCost', 
  'externalCost', 
  'totalCost', 
  'totalEfficiency', 
  'rawAllocationOnly', 
  'properties.cluster', 
  'properties.container', 
  'properties.namespace', 
  'properties.pod', 
  'properties.node', 
  'properties.controller', 
  'properties.controllerKind', 
  'properties.providerID'
]

df.to_csv('output.csv', sep=',', encoding='utf-8', index=False, columns=columns)

s3 = boto3.resource('s3')    
s3.Bucket(bucket_name).upload_file('./output.csv','{}/{}.csv'.format(start.strftime('year=%Y/month=%m/day=%d'), cluster_id))