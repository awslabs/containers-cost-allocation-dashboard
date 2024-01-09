# Requirements

Following are the requirements before deploying this solution:

* An S3 bucket, which will be used to store the Kubecost data.  
It is not created by the Terraform module, you need to create it in advance.
* Athena workgroup, if you choose to not create it using the Terraform module.  
Notice that by default, the Terraform module will create an Athena workgroup.  
You can choose to not create it, and then this requirement becomes relevant.
* An S3 bucket to be used for the Athena workgroup query results location (see [detailed instructions](#configure-athena-query-results-location))
* QuickSight Enterprise Edition, with the following (see [detailed instructions](#quicksight-requirements)):
  * Permissions to access the Kubecost S3 bucket and the Athena query results location S3 bucket
  * Enough SPICE capacity
* For each EKS cluster, have the following:
  * An [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).  
  The IAM OIDC Provider must be created in the EKS cluster's account. 
  * Kubecost deployed in the EKS cluster. In addition, the following is optional but recommended:
    * The get the most accurate cost data from Kubecost (such as RIs, SPs and Spot), [integrate it with CUR](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations) and [Spot Data Feed](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations/aws-spot-instances).
    * To get accurate network costs from Kubecost, please follow the [Kubecost network cost allocation guide](https://docs.kubecost.com/using-kubecost/getting-started/cost-allocation/network-allocation) and deploy [the network costs DaemonSet](https://docs.kubecost.com/install-and-configure/advanced-configuration/network-costs-configuration).   
    * To see K8s annotations in each allocation, you must [enable Annotation Emission in Kubecost](https://docs.kubecost.com/install-and-configure/advanced-configuration/annotations)
    * To see node-related data for each allocation, [add node labels in Kubecost's values.yaml](https://github.com/kubecost/cost-analyzer-helm-chart/blob/develop/cost-analyzer/values.yaml).  
    See more information in the [Adding Node Labels](#adding-node-labels) section
* Terraform 1.3.x or higher
* Helm 3.x or higher 
* The `cid-cmd` tool ([install with PIP](https://pypi.org/project/cid-cmd/))

Please continue reading the below sections.  
They include more detailed instructions for some of the above requirements. 

## Kubecost S3 Exporter Container

### Setting Requests and Limits 

As explained in [`ARCHITECTURE.md`](ARCHITECTURE.md), this solution deploys a container that collects data from Kubecost.  
This container currently doesn't have requests and limits set.  
It's highly advised that you first test it in a dev/QA environment that is similar to your production environment.  
During testing, monitor the CPU and RAM usage of the container, and set the requests and limits accordingly.

## Kubecost Requirements

### Adding Node Labels

The QuickSight dashboard includes the capability to group and filter allocations by node-related data.  
This data is based on K8s node labels, which must be available in the Kubecost Allocation API.  
The following node labels are support by the QuickSight dashboard:

    node.kubernetes.io/instance-type
    topology.kubernetes.io/region
    topology.kubernetes.io/zone
    kubernetes.io/arch
    kubernetes.io/os
    eks.amazonaws.com/nodegroup
    eks.amazonaws.com/nodegroup_image
    eks.amazonaws.com/capacityType
    karpenter.sh/capacity-type
    karpenter.sh/provisioner-name
    karpenter.k8s.aws/instance-ami-id

However, by default, the Kubecost Allocation API response only includes a few specific node labels.  
For the QuickSight dashboard to support all of the above node labels, you must add them to [Kubecost values.yaml](https://github.com/kubecost/cost-analyzer-helm-chart/blob/develop/cost-analyzer/values.yaml).

Here's an example of adding these node labels using `--set` option when running `helm upgrade -i`:

    helm upgrade -i kubecost \
    oci://public.ecr.aws/kubecost/cost-analyzer --version 1.103.4 \
    --namespace kubecost \
    -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml \
    --set networkCosts.enabled=true \
    --set networkCosts.config.services.amazon-web-services=true \
    --set kubecostModel.allocation.nodeLabels.includeList="node.kubernetes.io\/instance-type\,topology.kubernetes.io\/region\,topology.kubernetes.io\/zone\,kubernetes.io\/arch\,kubernetes.io\/os\,eks.amazonaws.com\/nodegroup\,eks.amazonaws.com\/nodegroup_image\,eks.amazonaws.com\/capacityType\,karpenter.sh\/capacity-type\,karpenter.sh\/provisioner-name\,karpenter.k8s.aws\/instance-ami-id"

## Athena Requirements

### Configure Athena Query Results Location

1. Create an S3 bucket that will be used for the Athena Workgroup Query Results Location.  
Note in case you decided to use an existing Athena workgroup:
You'll have to give the workgroup name as an input in a Terraform variable (documented separately in the Terraform README.md).
2. Set Query Results Location in the Athena Workgroup Settings:
If you decided to use an existing Athena workgroup, you need to set Athena workgroup Query Results Location yourself.  
In this case, follow the ["Set Query Results Location in the Athena Workgroup Settings section"](#set-query-results-location-in-the-athena-workgroup-settings).  
Otherwise, skip it.

#### Set Query Results Location in the Athena Workgroup Settings

Navigate to Athena Console -> Administration -> Workgroups:
![Screenshot of Athena Workgroups Page](./screenshots/athena_workgroups_page.png)

Click on the relevant Workgroup, and you'll see the Workgroup settings:
![Screenshot of Athena Workgroups Settings View](./screenshots/athena_workgroup_settings_view.png)

If the "Query result location" field is empty, go back to the Workgroups page, and edit the Workgroup settings:
![Screenshot of Athena Workgroups Page Edit Workgroup](./screenshots/athena_workgroups_page_edit_workgroup.png)

In the settings page, set the Query results location.  
Optionally (recommended), encrypt the query results, and save:
![Screenshot of Athena Workgroup Settings Edit](./screenshots/athena_workgroup_settings_edit.png)

You can also review the [following document](https://docs.aws.amazon.com/athena/latest/ug/querying.html#query-results-specify-location-workgroup) for more information

## QuickSight Requirements

### Configure QuickSight Permissions for the S3 Buckets

1. Navigate to “Manage QuickSight → Security & permissions”
2. Under “Access granted to X services”, click “Manage”
3. Under “S3 Bucket”:
   1. Check the checkbox for the S3 bucket you created for the Kubecost data.  
   You only need to check the checkbox next to the S3 bucket name for this bucket.  
   No need to check the checkbox under "Write permission for Athena Workgroup" for  this bucket.
   2. Check the checkbox for the S3 bucket you created for the Kubecost data.  
   Make sure you check both the checkbox next to the S3 bucket name and the checkbox under "Write permission for Athena Workgroup".
4. Click "Finish" and "Save".

### Verifying Enough QuickSight SPICE Capacity

Make sure you have enough QuickSight SPICE capacity to create the QuickSight dataset and store the data.  
The required capacity depends on the size of your EKS clusters from which Kubecost data is collected.  
You may start with small SPICE capacity and adjust as needed.  
Make sure it's at least larger than 0, so Terraform can create the QuickSight dataset.  
Make sure that you purchase SPICE capacity in the region where you intend to deploy the dashboard

To add SPICE capacity, follow [this document](https://docs.aws.amazon.com/quicksight/latest/user/managing-spice-capacity.html).
