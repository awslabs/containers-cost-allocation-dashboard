
# EKS Insights Dashboard

This is an integration of Kubecost with AWS CID (Cloud Intelligence Dashboards) to create the EKS Insights Dashboard.<br />
This dashboard is meant to provide a breakdown of the EKS in-cluster costs in multi-cluster environment, in a single-pane-of-glass alongside the other CID dashboards.

## Architecture

The following is the solution's architecture:

![Screenshot of the solution's architecture](./screenshots/kubecost_cid_architecture.png)

### Solution's Components

The solution is composed of the following resources:

* An S3 bucket that stores the Kubecost data (should be pre-created, see "Requirements" section)
* A CronJob controller (that is used to create a data collection pod) and Service Account.<br />
Both should be deployed on each EKS cluster, using a Terraform module (that invokes Helm) that is provided as part of this solution.<br />
You can also deploy these resources directly using the Helm chart that is provided as part of this solution.<br />
The data collection pod is referred to as Kubecost S3 Exporter throughout some parts of the documentation.
* The following AWS resources (all are deployed using a Terraform module that is provided as part of this solution):
  * IAM Role for Service Account (in the EKS cluster's account) and a parent IAM role (in the S3 bucket's account) for each cluster.<br />
    This is to support cross-account authentication between the data collection pod and the S3 bucket, using IAM role chaining. 
  * AWS Glue Database 
  * AWS Glue Table
  * AWS Glue Crawler (along with its IAM Role and IAM Policy)

### High-Level Logic

1. The CronJob K8s controller runs daily and creates a pod that collects cost allocation data from Kubecost. It runs the following API calls:<br />
The [Allocation API on-demand query (experimental)](https://docs.kubecost.com/apis/apis/allocation#querying-on-demand-experimental) to retrieve the cost allocation data.<br />
The [Assets API](https://docs.kubecost.com/apis/apis/assets-api) to retrieve the assets' data.<br />
It always collects the data between 72 hours ago 00:00:00 and 48 hours ago 00:00:00.<br />
2. Once data is collected, it's then converted to a Parquet, compressed and uploaded to an S3 bucket of your choice. This is when the CronJob finishes<br />
3. The data is made available in Athena using AWS Glue Database, AWS Glue Table and AWS Glue Crawler.<br />
The AWS Glue Crawler runs daily (using a schedule that you define), to create or update partitions.
4. QuickSight uses the Athena table as a data source to visualize the data

### Cross-Account Authentication Logic

This solution uses IRSA with IAM role chaining, to support cross-account authentication.<br />
For each EKS cluster, the Terraform module that's provided with this solution, will create:

* A child IRSA IAM role in the EKS cluster's account and region
* A parent IAM role in the S3 bucket's account

The child IRSA IAM role will have a Trust Policy that trusts the IAM OIDC Provider ARN.<br />
It's also specifically narrowed down using `Condition` element, to trust it only from the relevant K8s Service Account and Namespace.<br />
The inline policy of the IRSA IAM role allows only the `sts:AssumeRole` action, only for the parent IAM role that was created for this cluster.<br />

The parent IAM role will have a Trust Policy that only trusts the chile IAM role ARN.<br />
The inline policy of the parent IAM role allows only the `s3:PutObject` action, only on the S3 bucket and specific prefix where the Kubecost files for this cluster are expected to be stored.

In addition, an S3 bucket policy sample is provided as part of this documentation (see below "S3 Bucket Specific Notes" section).<br />
The Terraform module that's provided with this solution does not create it, because it doesn't create the S3 bucket.<br />
It's up to you to use it on your S3 bucket. 

## Requirements

1. An S3 bucket, which will be used to store the Kubecost data
2. QuickSight Enterprise with CID deployed
3. Terraform and Helm installed 
4. The `cid-cmd` tool ([install with PIP](https://pypi.org/project/cid-cmd/)) installed

For each EKS cluster, have the following:

1. An [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).<br />
The IAM OIDC Provider must be created in the EKS cluster's account and region.
2. Kubecost (free tier is enough) deployed in the EKS cluster.<br />
The get the most accurate data from Kubecost, it's recommended to [integrate it with CUR](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations).<br />
To get network costs, you should follow the [Kubecost network cost allocation guide](https://docs.kubecost.com/using-kubecost/getting-started/cost-allocation/network-allocation) and deploy [the network costs Daemonset](https://docs.kubecost.com/install-and-configure/advanced-configuration/network-costs-configuration).

Please continue reading the specific sections “S3 Bucket Specific Notes”, “Configure Athena Query Results Location” and “Configure QuickSight Permissions”. 

### S3 Bucket Specific Notes

You may create an S3 Bucket Policy on the bucket that you create to store the Kubecost data.<br />
In this case, below is a recommended bucket policy to use.<br />
This bucket policy, along with the identity-based policies of all the identities in this solution, provide minimum access:

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    "arn:aws:s3:::kubecost-data-collection-bucket",
                    "arn:aws:s3:::kubecost-data-collection-bucket/*"
                ],
                "Condition": {
                    "Bool": {
                        "aws:SecureTransport": "false"
                    },
                    "StringNotEquals": {
                        "aws:PrincipalArn": [
                            "arn:aws:iam::333333333333:role/<your_management_role>",
                            "arn:aws:iam::333333333333:role/kubecost_glue_crawler_role",
                            "arn:aws:iam::333333333333:role/service-role/aws-quicksight-service-role-v0"
                        ],
                        "aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"
                    }
                }
            }
        ]
    }

This S3 bucket denies all principals from performing all S3 actions, except the principals in the `Condition` section.<br />
The list of principals shown in the above bucket policy are as follows:

* The `arn:aws:iam::333333333333:role/<your_management_role>` principal:<br />
This principal is an example of an IAM Role you may use to manage the bucket.
Add the IAM Roles that will allow you to perform administrative tasks on the bucket.
* The `arn:aws:iam::333333333333:role/kubecost_glue_crawler_role` principal:<br />
This principal is the IAM Role that will be attached to the Glue Crawler when it's created by Terraform.<br />
You must add it to the bucket policy, so that the Glue Crawler will be able to crawl the bucket.
* The `arn:aws:iam::333333333333:role/service-role/aws-quicksight-service-role-v0` principal:<br />
This principal is the IAM Role that will is automatically created for QuickSight.<br />
If you use a different role, please change it in the bucket policy.<br />
You must add this role to the bucket policy, for proper functionality of the QuickSight dataset that is created as part of this solution.
* The `aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"` condition:<br />
This condition identifies all the EKS clusters from which the Kubecost S3 Exporter pod will communicate with the bucket.<br />
When Terraform creates the IAM roles for the pod to access the S3 bucket, it tags the parent IAM roles with the above tag.<br />
This tag is automatically being used in the IAM session when the Kubecost S3 Exporter pod authenticates.<br />
The reason for using this tag is to easily allow all EKS clusters running the Kubecost S3 Exporter pod, in the bucket policy, without reaching the bucket policy size limit.<br />
The other alternative is to specify all the parent IAM roles that represent each cluster one-by-one.<br />
With this approach, the maximum bucket policy size will be quickly reached, and that's why the tag is used.

The resources used in this S3 bucket policy include:

* The bucket name, to allow access to it
* All objects in the bucket, using the `arn:aws:s3:::kubecost-data-collection-bucket/*` string.<br />
The reason for using a wildcard here is that multiple principals (multiple EKS clusters) require access to different objects in the bucket.<br />
Using specific objects for each principal will result in a longer bucket policy that'll eventually exceed the bucket policy size limit.<br />
The identity policy (the parent IAM role) that is created as part of this solution for each cluster, specifies only the specific prefix and objects.<br >
Considering this, the access to the S3 bucket is more specific than what's specified in the "Resources" part of this bucket policy.

### Configure Athena Query Results Location

To set the Athena Query Results Location, follow both steps below.

#### Step 1: Set Query Results Location in the Athena Query Editor

Navigate to Athena Console -> Query Editor -> Settings:
![Screenshot of Athena Query Editor Settings View](./screenshots/athena_query_editor_view_settings.png)

If the "Query result location" field is empty, click "Manage".<br />
Then, set the Query result location, optionally (recommended) encrypt the query results, and save:
![Screenshot of Athena Query Editor Settings Edit](./screenshots/athena_query_editor_manage_settings.png)

#### Step 2: Set Query Results Location in the Athena Workgroup Settings

Navigate to Athena Console -> Administration -> Workgroups:
![Screenshot of Athena Workgroups Page](./screenshots/athena_workgroups_page.png)

Click on the relevant Workgroup, and you'll see the Workgroup settings:
![Screenshot of Athena Workgroups Settings View](./screenshots/athena_workgroup_settings_view.png)

If the "Query result location" field is empty, go back to the Workgroups page, and edit the Workgroup settings:
![Screenshot of Athena Workgroups Page Edit Workgroup](./screenshots/athena_workgroups_page_edit_workgroup.png)

In the settings page, set the Query results location, optionally (recommended) encrypt the query results, and save:
![Screenshot of Athena Workgroup Settings Edit](./screenshots/athena_workgroup_settings_edit.png)

### Configure QuickSight Permissions

1. Navigate to “Manage QuickSight → Security & permissions”
2. Under “Access granted to X services”, click “Manage”
3. Under “S3 Bucket”, check the S3 bucket you create, and check the “Write permissions for Athena Workgroup” for this bucket

Note - if at step 2 above, you get the following error:

*Something went wrong*
*For more information see Set IAM policy (https://docs.aws.amazon.com/console/quicksight/iam-qs-create-users)*

1. Navigate to the IAM console
2. Edit the QuickSight-managed S3 IAM Policy (usually named AWSQuickSightS3Policy
3. Add the S3 bucket in the same sections of the policy where you have your CUR bucket

## Deployment

There are 3 high-level steps to deploy the solution:

1. Build an image using `Dockerfile` and push it
2. Deploy both the AWS resources and the data collection CronJob using Terraform and Helm
3. Deploy the QuickSight dashboard using `cid-cmd` tool

### Step 1: Build and Push the Container Image

We do not provide a public image, so you'll need to build an image and push it to the registry and repository of your choice.<br />
In this section, choose either "Build and Push for a Single Platform" or "Build and Push for Multiple Platforms".

#### Build and Push for a Single Platform

Build for a platform as the source machine:

    docker build -t <registry_url>/<repo>:<tag> .

Build for a specific target platform:

    docker build --platform linux/amd64 -t <registry_url>/<repo>:<tag> .

Push:

    docker push <registry_url>/<repo>:<tag>

#### Build and Push for Multiple Platforms

    docker buildx build --push --platform linux/amd64,linux/arm64/v8 --tag <registry_url>/<repo>:<tag> .

### Step 2: Deploy the AWS and K8s Resources

This solution currently provides a Terraform module for deployment of both the AWS the K8s resources.<br />
There are 2 options to use it:
* Deployment Option 1: Deploy both the AWS resources and the K8s resources using Terraform (K8s resources are deployed by invoking Helm)
* Deployment Option 2: Deploy only the AWS resources using Terraform, and deploy the K8s resources using the `helm` command.<br />
With this option, Terraform will create a cluster-specific `values.yaml` file (with a unique name) for each cluster, which you can use

You can use a mix of these options.<br />
On some clusters, you can choose to deploy the K8s resources by having Terraform invoke Helm (the first option).<br />
On other clusters, you can choose to deploy the K8s resources yourself using the `helm` command (the second option).

#### Deployment Option 1

With this deployment option, Terraform deploys both the AWS resources and the K8s resources (by invoking Helm).

Please follow the instructions under `terraform/kubecost_cid_terraform_module/README.md`.<br />
For the initial deployment, you need to go through the "Requirements", "Structure" and "Initial Deployment" sections.<br />
Once you're done with Terraform, continue to step 3 below.

#### Deployment Option 2

With this deployment option, Terraform deploys only the AWS resources, and the K8s resources are deployed using the `helm` command.

1. Please follow the instructions under `terraform/kubecost_cid_terraform_module/README.md`.<br />
For the initial deployment, you need to go through the "Requirements", "Structure" and "Initial Deployment" sections.<br />
When reaching the "Create an Instance of the `kubecost_s3_exporter` Module and Provide Module-Specific Inputs", do the following:<br />
Make sure that as part of the optional module-specific inputs, you use the `invoke_helm` input with value of `false`.

2. After successfully executing `terraform apply` (the last step - step 4 - of the "Initial Deployment" section), Terraform will create the following:<br /> 
Per cluster for which you used the `invoke_helm` input with value of `false`, a YAML file will be created containing the Helm values for this cluster.<br />
The YAML file for each cluster will be named `<cluster_account_id>_<cluster_region>_<cluster_name>_values.yaml`.<br />
The YAML files will be created in the `helm/kubecost_s3_exporter/clusters_values` directory.

3. For each cluster, deploy the K8s resources by executing Helm

Executing Helm when you're still in the Terraform `deploy` directory

    helm upgrade -i kubecost-s3-exporter ../../../helm/kubecost_s3_exporter/ -n <namespace> --values ../../../helm/kubecost_s3_exporter/clusters_values/<cluster>.yaml --create-namespace --kube-context <cluster_context>

Executing Helm when from the `helm` directory

    helm upgrade -i kubecost-s3-exporter kubecost_s3_exporter/ -n <namespace> --values kubecost_s3_exporter/clusters_values/<cluster>.yaml --create-namespace --kube-context <cluster_context>

Once you're done, continue to step 3 below.

### Step 3: Dashboard Deployment

From the `cid` folder, run `cid-cmd deploy --resources eks_insights_dashboard.yaml`.<br />
The output should be similar to the below:

    CLOUD INTELLIGENCE DASHBOARDS (CID) CLI 0.2.3 Beta
    
    Loading plugins...
        Core loaded
        Internal loaded
    
    
    Checking AWS environment...
        profile name: <profile_name>
        accountId: <account_id>
        AWS userId: <user_id>
        Region: <region>
    
    
    
    ? [dashboard-id] Please select dashboard to install: (Use arrow keys)
     » [cudos] CUDOS Dashboard
       [cost_intelligence_dashboard] Cost Intelligence Dashboard
       [kpi_dashboard] KPI Dashboard
       [ta-organizational-view] Trusted Advisor Organizational View
       [trends-dashboard] Trends Dashboard
       [compute-optimizer-dashboard] Compute Optimizer Dashboard
       [eks_insights] EKS Insights

From the list, choose `[eks_insights] EKS Insights`.<br />
After choosing, wait for dashboards discovery to be completed, and then the additional output should be similar to the below:

    ? [dashboard-id] Please select dashboard to install: [eks_insights] EKS Insights
    Discovering deployed dashboards...  [####################################]  100%  "CUDOS Dashboard" (cudos)
    
    Required datasets:
     - eks_insights
    
    
    Looking by DataSetId defined in template...complete
    
    There are still 1 datasets missing: eks_insights
    Creating dataset: eks_insights
    Detected views:
    
    ? [athena-database] Select AWS Athena database to use: (Use arrow keys)
     » <cur_db>
       kubecost_db
       spectrumdb

From the list, choose the Athena database that was created by the Terraform template.<br />
If you didn't change the AWS Glue Database name in the Terraform template, then it'll be `kubecost_db` - please choose it.
After choosing, wait for the dataset to be created, and then the additional output should be similar to the below:

    ? [athena-database] Select AWS Athena database to use: kubecost_db
    Dataset "eks_insights" created
    Latest template: arn:aws:quicksight:<region_code>:<account_id>:template/eks_insights/version/1
    Deploying dashboard eks_insights
    
    #######
    ####### Congratulations!
    ####### EKS Insights is available at: https://<region_code>.quicksight.aws.amazon.com/sn/dashboards/eks_insights
    #######
    
    ? [share-with-account] Share this dashboard with everyone in the QuickSight account?: (Use arrow keys)
     » yes
       no

Choose whether to share the dashboard with everyone in this account.<br />
This selection will complete the deployment.<br />

Note:<br />
Data won't be available in the dashboard at least until the first time the data collection pod runs and collector data.
You must have data from at lest 72 hours ago in Kubecost for the data collection pod to collect data.

## Post-Deployment Steps

### Share the Dataset with Users

Share the dataset with users that are authorized to make changes to it:

1. Login to QuickSight, then click on the person icon on the top right, and click "Manage QuickSight"
2. On the left pane, navigate to "Manage assets", then choose "Datasets"
3. From the list, choose the `eks_insights` dataset (ID `e88edf48-f2cd-4c23-b6a4-e2b3034e2c41`)
4. Click "Share", select the desired permissions, start typing your user or group, select it and click "Share"
5. Navigate back to “Datasets” on the main QuickSight menus on the left, click the eks_insights dataset, and verify that the refresh status shows as “Completed” (It may take a few minutes to complete).<br />
Once it's completed - the dashboard is ready to be used, and you can navigate to “Dashboards”, click the EKS Insights dashboard, and start using the dashboard.

Please continue to the next steps to set dataset refresh (mandatory), and optionally share the dashboard with users and create an Analysis from the dashboard

### Set Dataset Refresh Schedule

A dataset refresh schedule needs to be set, so that the data from Athena will be fresh daily in QuickSight:

1. Login to QuickSight as a user that has "Owner" permissions to the dataset (you set it in the previous step)
2. Navigate to "Datasets" and click on the `eks_insights` dataset
3. Under "Refresh" tab, click "ADD NEW SCHEDULE"
4. Select "Incremental refresh", and click "CONFIGURE INCREMENTAL REFRESH"
5. On "Date column", make sure that "window.start" is selected
6. Set "Window size (number)" to "4", set "Window size (unit)" to "Days", and click "CONTINUE".<br />
Notice that any value that is less than "4" in the "Window size (number)" will miss some data.
7. Select "Timezone" and "Start time".<br />
Notice that these options set the refresh schedule.<br />
The refresh schedule should be at least 2 hours after the K8s CronJob schedule.<br />
This is because 1 hour after the CronJob runs, the AWS Glue Crawler runs.<br />
8. Set the "Frequency" to "Daily" and click "SAVE"

### Share the Dashboard with Users

To share the dashboard with users, for them to be able to view it and create Analysis from it, see the following link:<br />
https://wellarchitectedlabs.com/cost/200_labs/200_cloud_intelligence/postdeploymentsteps/share/

### Create an Analysis from the Dashboard

Create an Analysis from the Dashboard, to edit it and create custom visuals:

1. Login to QuickSight as a user that is allowed to save the dashboard as Analysis
2. Navigate to "Dashboards" and click the `EKS Insights`
3. On the top right, click the "Save as" icon (refresh the dashboard if you don't see it), name the Analysis, then click "SAVE" - you'll be navigated to the Analysis
4. You can edit the Analysis as you wish, and save it again as a dashboard, by clicking the "Share" icon on the top right, then click "Publish dashboard"

## Maintenance

After the solution is initially deployed, you might want to make changes.<br />
Below are instruction for some common changes that you might do after the initial deployment.

### Deploying on Additional Clusters

To add additional clusters to the dashboard, you need to add them to the Terraform module and apply it.<br />
Please follow the "Maintenance -> Deploying on Additional Clusters" part under `terraform/kubecost_cid_terraform_module/README.md`.<br />
Wait for the next schedule of the Kubecost S3 Exporter and QuickSight refresh, so that it'll collect the new data.<br />

Alternatively, you can run the Kubecost S3 Exporter on-demand according to "Running the Kubecost S3 Exporter Pod On-Demand" section.<br />
Then, manually run the Glue Crawler and manually refresh the QuickSight dataset.

### Adding/Removing Labels to/from the Dataset

After the initial deployment, you might want to add or remove labels for some or all clusters, to/from the dataset.<br />
To do this, perform the following:

1. Add/remove the labels to/from the Terraform module and apply it.<br />
Please follow the "Maintenance -> Adding/Removing Labels to/from the Dataset" part under `terraform/kubecost_cid_terraform_module/README.md`.
2. Wait for the next Kubecost S3 Exporter schedule so that it'll collect the labels.<br />
Alternatively, you can run the Kubecost S3 Exporter on-demand according to "Running the Kubecost S3 Exporter Pod On-Demand" section.<br />
3. Login to QuickSight, navigate to "Datasets", click on the `eks_insights` dataset, click "EDIT DATASET", and click "SAVE & PUBLISH".<br/>
Wait the full refresh is done, and the new set of labels should be present in the analysis.<br />
For it to be available in the dashboard, export the analysis to a dashboard.

### Running the Kubecost S3 Exporter Pod On-Demand

In some cases, you'd like to run the Kubecost S3 Exporter pod on-demand.<br />
For example, you may want to test it, or you may have added some data and would like to see it immediately.<br />
To run the Kubecost S3 Exporter pod on-demand, run the following command (replace `<namespace>` with your namespace and `<context>` with your cluster ARN:

    kubectl create job --from=cronjob/kubecost-s3-exporter kubecost-s3-exporter1 -n <namespace> --context <context>

You can see the status by running `kubectl get all -n <namespace> --context <context>`

### Getting Logs from the Kubecost S3 Exporter Pod

To see the logs of the Kubecost S3 Exporter pod, you need to first get the list of pods by running the following command:

    kubectl get all -n <namespace> --context <context>

Then, run the following command to get the logs:

    kubectl logs <pod> -c kubecost-s3-exporter -n <namespace> --context <context>

## Cleanup

### QuickSight Cleanup

1. Delete any analysis you created from the dashboard
2. Delete the dashboard
3. Delete the dataset

### AWS and K8s Resources Cleanup

1. Follow the "Complete Cleanup" section in the Terraform README.md, located in the `terraform/kubecost_cid_terraform_module/README.md` directory
2. Manually remove the CloudWatch Log Stream that was created by the AWS Glue Crawler
3. Empty and delete the S3 bucket you created

### Helm K8s Resources Cleanup

For clusters on which the K8s resources were deployed using "Deployment Option 2", run the following Helm command per cluster:

    helm uninstall kubecost-s3-exporter -n <namespace> --kube-context <cluster_context>

### Remove Namespaces

For each cluster, remove the namespace by running `kubectl delete ns <namespace> --context <cluster_context>` per cluster.
