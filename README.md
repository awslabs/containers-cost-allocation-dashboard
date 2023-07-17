
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
  * AWS Secrets Manager Secret (if TLS is enabled)

### High-Level Logic

1. The CronJob K8s controller runs daily and creates a pod that collects cost allocation data from Kubecost. It runs the following API calls:<br />
The [Allocation API](https://docs.kubecost.com/apis/apis-overview/allocation) to retrieve the cost allocation data.<br />
The [Assets API](https://docs.kubecost.com/apis/apis-overview/assets-api) to retrieve the assets' data.<br />
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

### Kubecost APIs Used by this Solution

The Kubecost APIs that are being used are:

* The [Allocation API](https://docs.kubecost.com/apis/apis-overview/allocation) to retrieve the cost allocation data
* The [Assets API](https://docs.kubecost.com/apis/apis-overview/assets-api) to retrieve the assets' data - specifically for the nodes

### Encrypting Data In-Transit

This solution supports encrypting the data between the data collection pod and the Kubecost pod, in-transit.<br />
To enable this, please follow the "Enabling Encryption In-Transit Between the Data Collection Pod and Kubecost Pod" section in the Appendix.

### Back-filling Past Data

This solution supports back-filling past data up to the Kubecost retention limits (15 days for the free tier, 30 days for the business tier).  
The back-filling is done automatically by the data collection pod if it identifies gaps in the S3 data compared to the Kubecost data.  
For more information and use-cases that the back-filling solution solves, see the "Back-filling Past Data" section in the Appendix.

### Logging

Logging is supported in this solution as follows:

1. The data collection container outputs logs to `stdout` or `stderr`. It does NOT support writing logs to an external logging server.  
This is to keep it simple and remove this heavy lifting task from the container.    
It's within your responsibility to run a sidecar container to collect the data collection container logs and write them to an external logging server.  
You're highly encouraged to do so, as the data collection container logs are available for a limited time in the cluster.
2. The AWS Glue Crawler writes logs to Amazon CloudWatch Logs.  
It'll create a Log Group and Log Stream the first time it runs, if those aren't available.
3. All management API made by the data collection container, can be viewed in Amazon CloudTrail (unless aren't supported by CloudTrail).  
S3 data events can also be logged in CloudTrail, but it requires configuration.  
It's within your responsibility to configure Amazon CloudTrail to log events.

## Requirements

1. An S3 bucket, which will be used to store the Kubecost data
2. QuickSight Enterprise
3. Athena Workgroup, if you choose to not create a custom Athena Workgroup using Terraform
4. An S3 bucket to be used for the Athena Workgroup query results location 
5. Terraform and Helm installed
6. The `cid-cmd` tool ([install with PIP](https://pypi.org/project/cid-cmd/)) installed

For each EKS cluster, have the following:

1. An [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).<br />
The IAM OIDC Provider must be created in the EKS cluster's account and region.
2. Kubecost deployed in the EKS cluster.<br />
Currently, only the free tier and the EKS-optimized bundle of Kubecost are supported.<br />
The get the most accurate cost data from Kubecost (such as RIs, SPs and Spot), it's recommended to [integrate it with CUR](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations) and [Spot Data Feed](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations/aws-spot-instances).<br />
To get accurate network costs from Kubecost, please follow the [Kubecost network cost allocation guide](https://docs.kubecost.com/using-kubecost/getting-started/cost-allocation/network-allocation) and deploy [the network costs DaemonSet](https://docs.kubecost.com/install-and-configure/advanced-configuration/network-costs-configuration).

Please continue reading the specific sections “S3 Bucket Specific Notes”, “Configure Athena Query Results Location” and “Configure QuickSight Permissions”. 

### S3 Bucket Specific Notes

#### Using an S3 Bucket Policy

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
                    "<your_kubecost_bucket_arn>",
                    "<your_kubecost_bucket_arn>/*"
                ],
                "Condition": {
                    "Bool": {
                        "aws:SecureTransport": "false"
                    },
                    "StringNotEquals": {
                        "aws:PrincipalArn": [
                            "arn:aws:iam::<account_id>:role/<your_bucket_management_role>",
                            "arn:aws:iam::<account_id>:role/kubecost_glue_crawler_role",
                            "arn:aws:iam::<account_id>:role/service-role/aws-quicksight-service-role-v0"
                        ],
                        "aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"
                    },
                    "NumericLessThan": {
                        "s3:TlsVersion": "1.2"
                    }
                }
            }
        ]
    }

This S3 bucket denies all principals from performing all S3 actions, except the principals in the `Condition` section.<br />
The list of principals shown in the above bucket policy are as follows:

* The `arn:aws:iam::<account_id>:role/<your_bucket_management_role>` principal:<br />
This principal is an example of an IAM Role you may use to manage the bucket.
Add the IAM Roles that will allow you to perform administrative tasks on the bucket.
* The `arn:aws:iam::<account_id>:role/kubecost_glue_crawler_role` principal:<br />
This principal is the IAM Role that will be attached to the Glue Crawler when it's created by Terraform.<br />
You must add it to the bucket policy, so that the Glue Crawler will be able to crawl the bucket.
* The `arn:aws:iam::<account_id>:role/service-role/aws-quicksight-service-role-v0` principal:<br />
This principal is the IAM Role that will be automatically created for QuickSight.<br />
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
Using specific objects for each principal will result in a longer bucket policy that will eventually exceed the bucket policy size limit.<br />
The identity policy (the parent IAM role) that is created as part of this solution for each cluster, specifies only the specific prefix and objects.<br >
Considering this, the access to the S3 bucket is more specific than what's specified in the "Resources" part of this bucket policy.

#### Setting Server-Side Encryption

It's highly recommended that server-side encryption is set on your S3 Bucket.  
See [this documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-encryption.html) for more information.  
Please note that starting January 5th, 2023, Amazon S3 encrypts new objets by default.  
See [this announcement](https://aws.amazon.com/blogs/aws/amazon-s3-encrypts-new-objects-by-default/) for more information.

### Configure Athena Query Results Location

The Terraform module creates a custom Athena Workgroup by default, with the option to choose not to.  
When choosing to create it, the below requirements aren't necessary, as they're created by the Terraform module.  
In this case, you can skip this section.  
When choosing to not create it, you're required to set the Query Results Location on your Athena Workgroup.  
In this case, continue with this section.

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
2. Edit the QuickSight-managed S3 IAM Policy (usually named `AWSQuickSightS3Policy`)
3. Add the S3 bucket in the same sections of the policy where you have your CUR bucket

## Deployment

There are 3 high-level steps to deploy the solution:

1. Build an image using `Dockerfile` and push it
2. Deploy both the AWS resources and the data collection CronJob using Terraform and Helm
3. Deploy the QuickSight dashboard using `cid-cmd` tool

### Step 1: Build and Push the Container Image

We do not provide a public image, so you'll need to build an image and push it to the registry and repository of your choice.<br />
For the registry, we recommend using Private Repository in Amazon Elastic Container Registry (ECR).<br />
You can find instructions on creating a Private Repository in ECR in [this document](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html).<br />
The name for the repository can be any name you'd like - for example, you can use `kubecost-s3-exporter`.<br />
If you decided to use Private Repository in ECR, you'll have to configure your Docker client to log in to it first, before pushing the image to it.<br />
You can find instructions on logging in to a Private Repository in ECR using Docker client, in [this document](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html).<br />

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

Executing Helm when in the `helm` directory

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
        profile name: <your_profile_name>
        accountId: <your_account_id>
        AWS userId: <your_user_id>
        Region: <your_region_code>
    
    
    
    ? [dashboard-id] Please select dashboard to install: (Use arrow keys)
       [cudos] CUDOS Dashboard
       [cost_intelligence_dashboard] Cost Intelligence Dashboard
       [kpi_dashboard] KPI Dashboard
       [ta-organizational-view] Trusted Advisor Organizational View
       [trends-dashboard] Trends Dashboard
       [compute-optimizer-dashboard] Compute Optimizer Dashboard
     » [eks_insights] EKS Insights

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
       <cur_db>
     » kubecost_db
       spectrumdb

From the list, choose the Athena database that was created by the Terraform template.<br />
If you didn't change the AWS Glue Database name in the Terraform template, then it'll be `kubecost_db` - please choose it.
After choosing, wait for the dataset to be created, and then the additional output should be similar to the below:

    ? [athena-database] Select AWS Athena database to use: kubecost_db
    Dataset "eks_insights" created
    Latest template: arn:aws:quicksight:<source_region_code>:<source_account_id>:template/eks_insights/version/1
    Deploying dashboard eks_insights
    
    #######
    ####### Congratulations!
    ####### EKS Insights is available at: https://<your_region_code>.quicksight.aws.amazon.com/sn/dashboards/eks_insights
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

## Update the Solution

The following steps should be done to update the solution when there's a new version.  
Notice that not all steps are always necessary - it depends on the changes in the new version. 

1. Build and push the Docker image (follow the same steps as in "Deployment -> Step 1: Build and Push the Container Image").  
Notice that if no changes were made in the Python data collection script, this step can be skipped.
2. Run `terraform apply` on the Terraform module, from the `deploy` directory.
Notice that if no changes were made in the Terraform module, this step can be skipped.  
If you're not sure, run `terraform apply`, and if there are no changes, Terraform will identify it and will make no changes.
3. If you used Helm separately to deploy the K8s resources, run `helm upgrade` on the new Helm chart.  
Notice that if no changes were made in the Helm chart, this step can be skipped.
4. Update the dashboard using the `cid-cmd update --recursive --force --resources eks_insights_dashboard.yaml`.  
Notice that if you customized the dashboard, make sure to keep a copy of the customized dashboard, update the original one, and customize again.  
See sample outputs below. [1][2]
5. Login to QuickSight, navigate to "Datasets", click on the `eks_insights` dataset, click "EDIT DATASET", and click "SAVE & PUBLISH"


[1] Expected output when there's an updated version:



    CLOUD INTELLIGENCE DASHBOARDS (CID) CLI 0.2.12 Beta
    
    Loading plugins...
        Core loaded
    
    
    Checking AWS environment...
        profile name: <your_profile_name>
        accountId: <your_account_id>
        AWS userId: <your_user_id>
        Region: <your_region_code>
    
    
    Discovering deployed dashboards...  [####################################]  100%  "EKS Insights" (eks_insights)
    
    ? [dashboard-id] Please select installation(s) from the list: EKS Insights (arn:aws:quicksight:<your_region_code>:<your_account_id>:dashboard/eks_insights, healthy, update available 6->10)
    
    Latest template: arn:aws:quicksight:<source_region_code>:<source_account_id>:template/eks_insights/version/10
    An update is available:
                       Deployed -> Latest
      CID Version      v0.1.4      v0.1.7
      TemplateVersion  6           10
    
    Required datasets:
     - eks_insights
    
    Updating dataset: "eks_insights"
    Detected views:
    Updated dataset: "eks_insights"
    Using dataset eks_insights: <dataset_id>
    
    Checking for updates...
    Deployed template: arn:aws:quicksight:<source_region_code>:<source_account_id>:template/eks_insights/version/6
    Latest template: arn:aws:quicksight:<source_region_code>:<source_account_id>:template/eks_insights/version/10
    
    Updating eks_insights
    Update completed
    
    #######
    ####### EKS Insights is available at: https://<your_region_code>.quicksight.aws.amazon.com/sn/dashboards/eks_insights
    #######
    Do you wish to open it in your browser? [y/N]: y

[2] Expected output when update is not required:

    CLOUD INTELLIGENCE DASHBOARDS (CID) CLI 0.2.12 Beta
    
    Loading plugins...
        Core loaded
    
    
    Checking AWS environment...
        profile name: <your_profile_name>
        accountId: <your_account_id>
        AWS userId: <your_user_id>
        Region: <your_region_code>
    
    
    Discovering deployed dashboards...  [####################################]  100%  "EKS Insights" (eks_insights)
    
    ? [dashboard-id] Please select installation(s) from the list: EKS Insights (arn:aws:quicksight:<your_region_code>:<your_account_id>:dashboard/eks_insights, healthy, up to date)
    
    Latest template: arn:aws:quicksight:<source_region_code>:<source_account_id>:template/eks_insights/version/10
    You are up to date!
      CID Version      v0.1.7
      TemplateVersion  10
    
    Required datasets:
     - eks_insights
    
    Updating dataset: "eks_insights"
    Detected views:
    Updated dataset: "eks_insights"
    Using dataset eks_insights: <dataset_id>
    
    Checking for updates...
    Deployed template: arn:aws:quicksight:<your_region_code>:<your_account_id>:template/eks_insights/version/10
    Latest template: arn:aws:quicksight:<your_region_code>:<your_account_id>:template/eks_insights/version/10
    
    ? [confirm-update] No updates available, should I update it anyway?: no

## Maintenance

After the solution is initially deployed, you might want to make changes.<br />
Below are instruction for some common changes that you might do after the initial deployment.

### Deploying on Additional Clusters

To add additional clusters to the dashboard, you need to add them to the Terraform module and apply it.<br />
Please follow the "Maintenance -> Deploying on Additional Clusters" part under `terraform/kubecost_cid_terraform_module/README.md`.<br />
Wait for the next schedule of the Kubecost S3 Exporter and QuickSight refresh, so that it'll collect the new data.<br />

Alternatively, you can run the Kubecost S3 Exporter on-demand according to "Running the Kubecost S3 Exporter Pod On-Demand" section.<br />
Then, manually run the Glue Crawler and manually refresh the QuickSight dataset.

### Adding/Removing Labels/Annotations to/from the Dataset

After the initial deployment, you might want to add or remove labels or annotations for some or all clusters, to/from the dataset.<br />
To do this, perform the following:

1. Add/remove the labels/annotations to/from the Terraform module and apply it.<br />
Please follow the "Maintenance -> Adding/Removing Labels/annotations to/from the Dataset" part under `terraform/kubecost_cid_terraform_module/README.md`.
2. Wait for the next Kubecost S3 Exporter schedule so that it'll collect the labels/annotations.<br />
Alternatively, you can run the Kubecost S3 Exporter on-demand according to "Running the Kubecost S3 Exporter Pod On-Demand" section.<br />
3. Login to QuickSight, navigate to "Datasets", click on the `eks_insights` dataset, click "EDIT DATASET", and click "SAVE & PUBLISH".<br/>
Wait the full refresh is done, and the new set of labels/annotations should be present in the analysis.<br />
For it to be available in the dashboard, export the analysis to a dashboard.

**_Note about annotations:_**

While K8s labels are included by default in Kubecost Allocation API response, K8s annotations aren't.  
To include K8s annotations in the Kubecost Allocation API response, following [this document](https://docs.kubecost.com/install-and-configure/advanced-configuration/annotations).

### Running the Kubecost S3 Exporter Pod On-Demand

In some cases, you'd like to run the Kubecost S3 Exporter pod on-demand.<br />
For example, you may want to test it, or you may have added some data and would like to see it immediately.<br />
To run the Kubecost S3 Exporter pod on-demand, run the following command (replace `<namespace>` with your namespace and `<context>` with your cluster ARN:

    kubectl create job --from=cronjob/kubecost-s3-exporter kubecost-s3-exporter1 -n <namespace> --context <context>

You can see the status by running `kubectl get all -n <namespace> --context <context>`.

Please note that due to the automatic back-filling solution, you can't run the data collection on-demand for data that already exists in S3.  
If data already exists for the date you'd like to run the collection for, you must delete the Parquet file for this date first.  
This will trigger the automatic back-filling solution to identify the missing date and back-fill it, when you run the data collection.    
Notice that this is possible only up to the Kubecost retention limit (15 days for the free tier, 30 days for the business tier).

### Getting Logs from the Kubecost S3 Exporter Pod

To see the logs of the Kubecost S3 Exporter pod, you need to first get the list of pods by running the following command:

    kubectl get all -n <namespace> --context <context>

Then, run the following command to get the logs:

    kubectl logs <pod> -c kubecost-s3-exporter -n <namespace> --context <context>

## Troubleshooting

This section includes some common issues and possible solutions.

### The Data Collection Pod is in Status of `Completed`, But There's No Data in the S3 Bucket

The data collection container collects data between 72 hours ago 00:00:00.000 and 48 hours ago 00:00:00.000.<br />
Your Kubecost server still have missing data in this timeframe.<br />
Please check the data collection container logs, and if you see the below message, it means you still don't have enough data:

    <timestamp> ERROR kubecost-s3-exporter: API response appears to be empty.
    This script collects data between 72 hours ago and 48 hours ago.
    Make sure that you have data at least within this timeframe.

In this case, please wait for Kubecost to collect data for 72 hours ago, and then check again.

### The Data Pod Container is in Status of `Error`

This could be for various reasons.<br />
Below are a couple of scenarios caught by the data collection container, and their logs you should expect to see.

#### A Connection Establishment Timeout

In case of a connection establishment timeout, the container logs will show the following log:

    <timestamp> ERROR kubecost-s3-exporter: Timed out waiting for TCP connection establishment in the given time ({connection_timeout}s). Consider increasing the connection timeout value.

In this case, please check the following:

1. That you specified the correct Kubecost API endpoint in the `kubecost_api_endpoint` input.
This should be the Kubecost cost-analyzer service.<br />
Usually, you should be able to specify `http://<service_name>.<namespace_name>:[port]`, and this DNS name will be resolved.
The default service name for Kubecost cost-analyzer service is `kubecost-cost-analyzer`, and the default namespace it's created in is `kubecost`.<br />
The default port the Kubecost cost-analyzer service listens on is TCP 9090.<br />
Unless you changed the namespace, service name or port, you should be good with the default value of the `kubecost_api_endpoint` input.<br />
If you changed any of the above, make sure you change the `kubecost_api_endpoint` input value accordingly.
2. If the `kubecost_api_endpoint` input has the correct value, try increasing the `connection_timeout` input value
3. If you still get the same error, check network connectivity between the data collection pod and the Kubecost cost-analyzer service

#### An HTTP Server Response Timeout

In case of HTTP server response timeout, the container logs will show one of the following logs (depends on the API being queried):

    <timestamp> ERROR kubecost-s3-exporter: Timed out waiting for Kubecost Allocation On-Demand API to send an HTTP response in the given time ({read_timeout}s). Consider increasing the read timeout value.

    <timestamp> ERROR kubecost-s3-exporter: Timed out waiting for Kubecost Assets API to send an HTTP response in the given time ({read_timeout}s). Consider increasing the read timeout value.

If this is for the Allocation On-Demand API call, please follow the recommendations in the "Clarifications on the Allocation On-Demand API" part on the Appendix.<br />
If this is for the Assets API call, please try increasing the `kubecost_assets_api_read_timeout` input value.

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

## Appendix

### Back-filling Past Data

This solution supports back-filling past data up to the Kubecost retention limits (15 days for the free tier, 30 days for the business tier).  
The back-filling is done automatically by the data collection pod if it identifies gaps in the S3 data compared to the Kubecost data.  
The way it works is as follows:

1. An environment variable is passed to the data collection pod (`BACKFILL_PERIOD_DAYS` in Helm, `backfill_period_days` in Terraform).  
The default value is 15 days (according to the Kubecost free tier retention limit), but it can be changed.
2. Every time the data collection pod runs, it performs the following:
   1. Identifies the available data in Kubecost for the back-fill period.  
   This is done by querying the Allocation API for the given period, in daily granularity and `cluster` aggregation.  
   This API call intentionally uses high granularity and high aggregation levels, because the cost data isn't the purpose of this call.  
   The purpose of this call is to identify the dates where Kubecost data is available.
   2. Identifies the available data in the S3 bucket for the back-fill period.  
   This is done by querying Amazon S3 API for the given bucket, using the `s3:ListObjectV2` API call.  
   The dates are then extracted from the Parquet files names.
   3. The dates extracted from Kubecost Allocation API and Amazon S3 `s3:ListObjectV2` API are compared.  
   If there are dates in the Kubecost API response that aren't available in the S3 bucket, data collection is performed from Kubecost for these dates.

On a regular basis, this logic is simply used to perform the daily data collection.  
It'll always identify one day gap between Kubecost and S3, and will collect the missing day.  
However, in cases of missing data for other dates, the above logic is used to back-fill the missing data.  
This is instead of simply running the data collection always on a given timeframe (e.g., 3 days ago), which will only work for daily collection.  
This automatic back-filling solution can fit the following use-cases:

1. Back-filling data for a newly deployed data collection pod, if Kubecost was already deployed on the same cluster for multiple days
2. Back-filling data for clusters that are regularly powered off for certain days:  
On the days they're powered off, the data collection pod isn't running, and therefore isn't collecting the data relative to those dates (3 days back).  
The missing data will be automatically back-filled the next time the job runs after the cluster was powered back up.
3. Back-filling for failed jobs:  
It could be that the data collection pod failed for some reason, more than the maximum number of job failures.  
Assuming the issue is fixed within the Kubecost retention limit, the missing data will be back-filled automatically the next time the job runs successfully.
4. Back-filling for accidental deletion of Parquet files:  
If Parquet files within the Kubecost retention limit timeframe were accidentally deleted, the missing data will be automatically back-filled.

Notes:

1. The back-filling solution supports back-filling data only up to the Kubecost retention limit (15 days for the free tier, 30 days for the business tier)
2. The back-filling solution is automatic, and does not support force-back-filling of data that already exists in the S3 bucket.
If you'd like to force-back-fill existing data, you must delete the Parquet file for the desired date, and then run the data collection.  
An example reason for such a scenario is that an issue was fixed or a feature was added to the solution, and you'd like it to be applied for past data.  
Notice that this is possible only up to the Kubecost retention limit (15 days for the free tier, 30 days for the business tier).

### Enabling Encryption In-Transit Between the Data Collection Pod and Kubecost Pod

By default, the Kubecost cost-analyzer-frontend service uses HTTP service to serve the UI/API endpoints, over TCP port 9090.<br />
For secure communication between the data collection pod and the Kubecost service, it's recommended to encrypt the data in-transit.<br />
To do that, you first need to enable TLS in Kubecost, and then enable communication over HTTPS in the data collection pod.<br />
Below you'll find the necessary steps to take.

#### Enabling TLS in Kubecost

At the time of writing this document, Kubecost doesn't have any public documentation on enabling TLS.<br />
This section will help you go through enabling TLS in Kubecost.<br />
This section does not intend to replace the Kubecost user guide, and if you have any doubts, please contact Kubecost support.

To enable TLS in Kubecost, please take the following steps:

1. Create a TLS Secret in the Kubecost namespace, for the server certificate and private key you intend to use in Kubecost.<br />
You can use the below `kubectl` command [1] to create the Secret object:<br />
Note that the private key must have no passphrase, otherwise, you'll get `error: tls: failed to parse private key` error when executing this command.<br />
It's advised that you'll use a server certificate that's signed by a root CA certificate, and not a self-signed certificate.

2. Enable TLS in Kubecost by changing the below values [2] in the Kubecost Helm chart.<br />
See full `helm` command example below [3].<br />
Once the Helm upgrade finishes successfully, you should see the Kubecost service listens on port 443.<br />
See example of the `kubectl get services` command output below [4].

#### Enabling TLS Communication in the Data Collection Pod

Enabling TLS in the data collection pod is done on per pod basis on each cluster.<br />
This is because the same is done on per pod basis in Kubecost, and Kubecost is installed separately on each cluster.<br />
Please take the following steps to enable TLS communication in the data collection pod:

1. In the `deploy/main.py` file, add the `kubecost_api_endpoint` variable to the module instance for the cluster.<br /> 
By default, if you don't add this variable to the module instance, the data collection pod uses `http://kubecost-cost-analyzer.kubecost:9090` to communicate with Kubecost.<br />
The URL you should to make sure the data collection pod uses TLS and use TCP port 443, must start with `https`.<br />
For example, use `https://kubecost-cost-analyzer.kubecost` (not port at the end means TCP port 443).
2. If you're using a self-signed server certificate in Kubecost (as doe in step 1 above), disable TLS verification in the data collection pod.<br />
Do so by adding `tls_verify` variable with value of `false`, in the module instance in `deploy/main.tf`.
The default value of `tls_verify` is `true`.<br />
This means that if the `kubecost_api_endpoint` uses an `https` URL and you're using a self-signed certificate in Kubecost, the data collection pod will fail to connect to Kubecost API.<br />
So in this case, you must disable TLS verification in the data collection pod.<br />
Please note that although at this point, the data in-transit will be encrypted, using a self-signed certificate is insecure.
3. If you're using a server certificate signed by a CA, in Kubecost, the data collection pod will need to pull the CA certificate, so that it can use it for certificate verification.<br />
   1. Add the CA certificate to the `kubecost_ca_certificates_list` variable in `modules/common/variables.tf`.<br >
   See an example in `examples/modules/common/variables.tf`.<br />
   This variable will be used by Terraform to create an AWS Secrets Manager Secret in the pipline account.<br />
   The `cert_path` key is mandatory, and must have the local full path to the CA certificate, including the file name.<br />
   The `cert_secret_name` is mandatory, and is a name of your choice, that will be used for the AWS Secrets Manager secret.<br />
   The `cert_secret_allowed_principals` is optional, and can be used to add additional IAM principals to be added to the secret policy.<br />
   When Terraform creates the secret, it'll also create a secret policy.<br />
   These principals will be added to the policy, in addition to the principal that will always be added to the policy to allow the cluster.
   2. Add the `kubecost_ca_certificate_secret_name` variable to the module instance of the cluster in `deploy/main.py`.<br />
   The value must be the same secret name that you used in the `cert_secret_name` key in the `kubecost_ca_certificates_list` variable.<br />
   This is used by Terraform to identify the secret to be used for this cluster to communicate with Kubecost, and pass it to Helm.<br />
   3. Make sure that the `tls_verify` variable is `true` (this should be the default).

Once the above procedure is done, the data sent between the data collection pod and Kubecost will be encrypted in-transit.<br />
Please be advised that all your other clients communicating with Kubecost must now use HTTPS too, and use the said CA certificate.<br>
Please note that Terraform does not create secret rotation configuration.<br />
You need to make sure you update the secret with a new CA certificate before it expires. 

[1] The `kubectl` command to use for creating TLS secret:

    kubectl create secret tls <secret_name> --cert=<path_to_cert/cert.pem> --key=<path_to_key/key.pem> -n <namespace> --context <cluster_context>

[2] The values to change in Kubecost Helm chart, to enable TLS:

    kubecostFrontend.tls.enabled=true
    kubecostFrontend.tls.secretName=<secret_name>

[3] Example `helm` command with the TLS flags:

    helm upgrade -i <release_name> oci://public.ecr.aws/kubecost/cost-analyzer --version <version> --namespace <namespace> --create-namespace -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml --set kubecostFrontend.tls.enabled=true --set kubecostFrontend.tls.secretName=<secret_name> --kube-context <cluster_context>

[4] Example `kubectl get services` command output:

    kubectl get services -n <namespace> --context <cluster_context>
    NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)            AGE
    kubecost-cost-analyzer            ClusterIP   <ip>             <none>        9003/TCP,443/TCP   199d