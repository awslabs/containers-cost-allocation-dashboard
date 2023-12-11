# Containers Cost Allocation (CCA) Dashboard

Welcome!
This repository contains a project for visualizing data from [Kubecost](https://www.kubecost.com/) in Amazon QuickSight as part of [CID (Cloud Intelligence Dashboards)](https://catalog.workshops.aws/awscid/en-US).   
Here we demonstrate how you can break down EKS in-cluster cost and usage in a multi-cluster environment, and visualize this data in QuickSight alongside the other CIDs, using data from a [self-hosted Kubecost pod](https://www.kubecost.com/products/self-hosted).

This project can work with any Kubecost tier:

* Kubecost EKS-optimized bundle
* Kubecost free tier
* Kubecost enterprise tier, with the following limitations:
  * Data for all clusters are included in a single file per day instead of file per cluster per day
  * AWS account ID will not be shown
  * The `eksclustername` dataset field will show the primary cluster name for any cluster.  
    Instead, you can customize the dashboard and use the `clusterid` field

Please note that OpenCost is not supported.

More information on the Kubecost EKS-optimized bundle can be found in the below resources:

* [Kubecost AWS page](https://www.kubecost.com/aws)
* [Launch blog post](https://aws.amazon.com/blogs/containers/aws-and-kubecost-collaborate-to-deliver-cost-monitoring-for-eks-customers/)
* [AMP integration blog post](https://aws.amazon.com/blogs/mt/integrating-kubecost-with-amazon-managed-service-for-prometheus/)
* [Multi-cluster visibility blog post](https://aws.amazon.com/blogs/containers/multi-cluster-cost-monitoring-using-kubecost-with-amazon-eks-and-amazon-managed-service-for-prometheus/)
* [Amazon Cognito integration blog post](https://aws.amazon.com/blogs/containers/securing-kubecost-access-with-amazon-cognito/)
* [EKS user guide](https://docs.aws.amazon.com/eks/latest/userguide/cost-monitoring.html)
* [Kubecost on the AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-jatxqd2ccqvgc?sr=0-1&ref_=beagle&applicationId=AWSMPContessa) 
* [EKS Blueprints Add-on](https://aws-quickstart.github.io/cdk-eks-blueprints/addons/kubecost/)
* [EKS Add-on](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html#workloads-add-ons-available-vendors)

More information on Kubecost pricing can be found [here](https://www.kubecost.com/pricing).  
Feature comparison between Kubecost tiers can be found [here](https://docs.kubecost.com/architecture/opencost-product-comparison).

## Architecture

This solution is composed of the following components (in high-level):
* A data collection pod (referred to as "Kubecost S3 Exporter" throughout some parts of the documentation).  
It's used to collect the data from Kubecost and upload it to an S3 bucket that you own.
* A pipeline that makes the data available to be queried in Athena
* A QuickSight dashboard, along with its QuickSight assets (data source, dataset)

The AWS resources in this solution are deployed using a Terraform module which is provided as part of it.  
The K8s resources in this solution are deployed using a Helm chart which is provided as part of it.  
It's invoked by Terraform by default, but you can choose to deploy it yourself.
The QuickSight dashboard is deployed using the `cid-cmd` CLI tool.

More detailed information on the architecture and logic are found in the [`ARCHITECTURE.md`](ARCHITECTURE.md) file.  
Before proceeding to the requirements and deployment of this solution, it's highly recommended you review.   
For information related to security in this project, please refer to the [`SECURITY.md`](SECURITY.md) file.

## Requirements

Before proceeding to the deployment of this solution, please complete the requirements, as outlined in the [`REQUIREMENTS.md`](REQUIREMENTS.md) file.

## Deployment

For instructions on deploying this solution, please refer to the [`DEPLOYMENT.md`](DEPLOYMENT.md) file.  
When done, proceed to the [Post-Deployment Steps](#post-deployment-steps) section.

## Post-Deployment Steps

Before proceeding to use the dashboard, please complete the post-deployment steps outlined in the [`POST_DEPLOYMENT.md`](POST_DEPLOYMENT.md) file.  
In addition, if you'd like to deploy the Kubecost-S3-Exporter on additional clusters:  
See the [Deploying on Additional Clusters section in the MAINTENANCE.md file](MAINTENANCE.md/.#deploying-on-additional-clusters).  
If you'd like to add/remove K8s labels/annotations to/from the dataset:  
See the [Adding/Removing Labels/Annotations to/from the Dataset section in the MAINTENANCE.md file](MAINTENANCE.md/.#addingremoving-labelsannotations-tofrom-the-dataset).

## Update the Solution

For update instructions, please refer to the [`UPDATE.md`](UPDATE.md) file.

## Maintenance

For instructions on common maintenance tasks related to this solution, please refer to the [`MAINTENANCE.md`](MAINTENANCE.md) file. 

## Troubleshooting

For instructions on troubleshooting common issues related to this solution, please refer to the [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) file.

## Cleanup

For instructions on cleanup, please refer to the [`CLEANUP.md`](CLEANUP.md) file.
