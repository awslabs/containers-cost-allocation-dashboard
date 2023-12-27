# Requirements

Following are the requirements before deploying this solution:

## AWS Requirements

* An S3 bucket, which will be used to store the Kubecost data.  
It is not created by the Terraform module, you need to create it in advance.
* QuickSight Enterprise Edition
* Athena workgroup, if you choose to not create it using the Terraform module.  
Notice that by default, the Terraform module will create an Athena workgroup.  
You can choose to not create it, and then this requirement becomes relevant.
* An S3 bucket to be used for the Athena workgroup query results location

## EKS Requirements

For each EKS cluster, have the following:

* An [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).  
The IAM OIDC Provider must be created in the EKS cluster's account. 
* Kubecost deployed in the EKS cluster. In addition, the following is optional but recommended:
  * The get the most accurate cost data from Kubecost (such as RIs, SPs and Spot), [integrate it with CUR](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations) and [Spot Data Feed](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations/aws-spot-instances).
  * To get accurate network costs from Kubecost, please follow the [Kubecost network cost allocation guide](https://docs.kubecost.com/using-kubecost/getting-started/cost-allocation/network-allocation) and deploy [the network costs DaemonSet](https://docs.kubecost.com/install-and-configure/advanced-configuration/network-costs-configuration).   
  * To see K8s annotations in each allocation, you must [enable Annotation Emission in Kubecost](https://docs.kubecost.com/install-and-configure/advanced-configuration/annotations)
  * To see node-related data for each allocation, [add node labels in Kubecost's values.yaml](https://github.com/kubecost/cost-analyzer-helm-chart/blob/develop/cost-analyzer/values.yaml#L484-L486).  
  See more information in the [Adding Node Labels](#adding-node-labels) section

## Deployment Requirements

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
For the QuickSight dashboard to support all of the above node labels, you must add them to [Kubecost values.yaml](https://github.com/kubecost/cost-analyzer-helm-chart/blob/develop/cost-analyzer/values.yaml#L484-L486).

Here's an example of adding these node labels using `--set` option when running `helm upgrade -i`:

    helm upgrade -i kubecost-eks \
    oci://public.ecr.aws/kubecost/cost-analyzer --version 1.103.4 \
    --namespace kubecost-eks \
    -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml \
    --set networkCosts.enabled=true \
    --set networkCosts.config.services.amazon-web-services=true \
    --set kubecostModel.allocation.nodeLabels.includeList="node.kubernetes.io\/instance-type\,topology.kubernetes.io\/region\,topology.kubernetes.io\/zone\,kubernetes.io\/arch\,kubernetes.io\/os\,eks.amazonaws.com\/nodegroup\,eks.amazonaws.com\/nodegroup_image\,eks.amazonaws.com\/capacityType\,karpenter.sh\/capacity-type\,karpenter.sh\/provisioner-name\,karpenter.k8s.aws\/instance-ami-id"

## Configure Athena Query Results Location

An Athena Workgroup can be used by this solution, which also requires setting Athena Query Results Location in the Workgroup.  
By default, Terraform will create an Athena Workgroup, but you can also choose that it won't.  
Depending on your choice, there are different requirements that you need to go though, before deployment.  
Please either proceed to the [Athena Requirements for Terraform-Created Workgroup](#athena-requirements-for-terraform-created-workgroup) or to the [Athena Requirements for Self-Created Workgroup](#athena-requirements-for-self-created-workgroup)

### Athena Requirements for Terraform-Created Workgroup

Following are the requirements when choosing the use the Terraform-Created Workgroup:

#### Step 1: Create an S3 bucket that will be used for the Athena Workgroup Query Results Location  

This S3 bucket will be used to write the Athena query results.  
You'll have to give this bucket name as an input in a Terraform variable (documented separately in the Terraform README.md). 

#### Step 2: Configure permissions in QuickSight to access the above S3 bucket  

In QuickSight, go to "Manage QuickSight" (top right), then "Security & permissions" on the left.  
Click "Manage" under "Access granted to X services", then select Athena and click "Next".  
Select the S3 bucket that you created above.  
Also, make sure you select S3 buckets required by other QuickSight data sources, otherwise you these data sources may lose access.  
Then, click "Finish" and "Save".

If you get an error as the below:

    We cannot update the IAM Role. The reason could be one or more from the following:
      The role does not explicitly trust QuickSight service principal.
      Following policies are either not attached to the QuickSight role or attached to more than one:
          arn:aws:iam::<account_id>:policy/service-role/AWSQuickSightS3Policy
      Make sure the credentials you're using have following permissions:
          iam:CreateRole, iam:CreatePolicy, iam:AttachRolePolicy, iam:CreatePolicyVersion, iam:DeletePolicyVersion, iam:ListAttachedRolePolicies, iam:GetRole, iam:GetPolicy, iam:DetachRolePolicy, iam:GetPolicyVersion and iam:ListPolicyVersions

Then you need to add the permissions directly in the IAM console.  
This easiest way to do it is to find the predefined IAM Role named `aws-quicksight-service-role-v0`.  
In it, there's an attached predefined IAM Policy named `AWSQuicksightAthenaAccess`.  
You can't edit it, so copy its contents (JSON), and create a new IAM Policy/inline policy.  
Paste the JSON you copied into the new policy, and change the bucket name to the one you created (make sure you end with a wildcard).  
Then, attach the policy to the IAM Role (unless you created an inline policy).

If you don't follow the above procedure, it'll result in the following error later when creating the QuickSight Data Source that uses the Athena Workgroup:  

    GENERIC_SQL_FAILURE: [Simba][AthenaJDBC](100071) An error has been thrown from the AWS Athena client. Unable to verify/create output bucket <bucket_name>


If you followed this process but didn't add wildcard in the end of the bucket resource in the IAM policy, it'll result in the following error later when creating the QuickSight Data Source:

    ACCESS_DENIED_TO_RESULT_STAGING_AREA [Simba][AthenaJDBC](100071) An error has been thrown from the AWS Athena client. Access denied when writing to location: s3://<bucket_name>/<file_name>

### Athena Requirements for Self-Created Workgroup

If you choose that Terraform won't create an Athena Workgroup for you, please follow the below requirements for the workgroup you plan to use:

#### Step 1: Create an S3 bucket that will be used for the Athena Workgroup Query Results Location  

This S3 bucket will be used to write the Athena query results.  

#### Step 2: Set Query Results Location in the Athena Workgroup Settings

Navigate to Athena Console -> Administration -> Workgroups:
![Screenshot of Athena Workgroups Page](./screenshots/athena_workgroups_page.png)

Click on the relevant Workgroup, and you'll see the Workgroup settings:
![Screenshot of Athena Workgroups Settings View](./screenshots/athena_workgroup_settings_view.png)

If the "Query result location" field is empty, go back to the Workgroups page, and edit the Workgroup settings:
![Screenshot of Athena Workgroups Page Edit Workgroup](./screenshots/athena_workgroups_page_edit_workgroup.png)

In the settings page, set the Query results location.  
Optionally (recommended), encrypt the query results, and save:
![Screenshot of Athena Workgroup Settings Edit](./screenshots/athena_workgroup_settings_edit.png)

#### Step 3: Configure permissions in QuickSight to access the above S3 bucket

Follow the same steps as in step 2 of the [Athena Requirements for Terraform-Created Workgroup](#athena-requirements-for-terraform-created-workgroup).  

## Configure QuickSight Permissions for the Kubecost Data S3 Bucket

1. Navigate to “Manage QuickSight → Security & permissions”
2. Under “Access granted to X services”, click “Manage”
3. Under “S3 Bucket”, check the S3 bucket you created for the Kubecost data

Note - if at step 2 above, you get the following error:

    Something went wrong
    For more information see Set IAM policy (https://docs.aws.amazon.com/console/quicksight/iam-qs-create-users)

1. Navigate to the IAM console
2. Edit the QuickSight-managed S3 IAM Policy (usually named `AWSQuickSightS3Policy`)
3. Add the S3 bucket in the same sections of the policy where you have your CUR bucket
