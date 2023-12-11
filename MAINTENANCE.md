# Maintenance

After the solution is initially deployed, you might want to make changes.  
Below are instruction for some common changes that you might do after the initial deployment.

## Deploying on Additional Clusters

To add additional clusters to the dashboard, you need to add them to the Terraform module and apply it.  
Please follow the [Maintenance -> Deploying on Additional Clusters part in the Terraform module README](terraform/cca_terraform_module/README.md/.#deploying-on-additional-clusters) file.  
Wait for the next schedule of the Kubecost S3 Exporter and QuickSight refresh, so that it'll collect the new data.  

Alternatively, you can run the Kubecost S3 Exporter on-demand according to [Running the Kubecost S3 Exporter Pod On-Demand](#running-the-kubecost-s3-exporter-pod-on-demand) section.  
Then, manually run the Glue Crawler and manually refresh the QuickSight dataset.

## Adding/Removing Labels/Annotations to/from the Dataset

After the initial deployment, you might want to add or remove labels or annotations for some or all clusters, to/from the dataset.  
To do this, perform the following:

1. Add/remove the labels/annotations to/from the Terraform module and apply it.  
Please follow the [Maintenance -> Adding/Removing Labels/annotations to/from the Dataset part in the Terraform module README](/terraform/kubecost_cid_terraform_module/README.md/.#addingremoving-labelsannotations-tofrom-the-dataset) file.
2. Wait for the next Kubecost S3 Exporter schedule so that it'll collect the labels/annotations.  
Alternatively, you can run the Kubecost S3 Exporter on-demand according to [Running the Kubecost S3 Exporter Pod On-Demand](#running-the-kubecost-s3-exporter-pod-on-demand) section.  

**_Note about annotations:_**

While K8s labels are included by default in Kubecost Allocation API response, K8s annotations aren't.  
To include K8s annotations in the Kubecost Allocation API response, follow [this document](https://docs.kubecost.com/install-and-configure/advanced-configuration/annotations).

## Running the Kubecost S3 Exporter Pod On-Demand

In some cases, you'd like to run the Kubecost S3 Exporter pod on-demand.  
For example, you may want to test it, or you may have added some data and would like to see it immediately.  
To run the Kubecost S3 Exporter pod on-demand, run the following command (replace `<namespace>` with your namespace and `<context>` with your cluster context:

    kubectl create job --from=cronjob/kubecost-s3-exporter kubecost-s3-exporter1 -n <namespace> --context <context>

You can see the status by running `kubectl get all -n <namespace> --context <context>`.

Please note that due to the automatic back-filling solution, you can't run the data collection on-demand for data that already exists in S3.  
If data already exists for the date you'd like to run the collection for, you must delete the Parquet file for this date first.  
This will trigger the automatic back-filling solution to identify the missing date and back-fill it, when you run the data collection.    
Notice that this is possible only up to the Kubecost retention limit (15 days for the free tier, 30 days for the business tier).

## Getting Logs from the Kubecost S3 Exporter Pod

To see the logs of the Kubecost S3 Exporter pod, you need to first get the list of pods by running the following command:

    kubectl get all -n <namespace> --context <context>

Then, run the following command to get the logs:

    kubectl logs <pod> -c kubecost-s3-exporter -n <namespace> --context <context>

