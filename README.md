
# EKS Insights Dashboard

This is an integration of Kubecost with AWS CID (Cloud Intelligence Dashboards) to create the EKS Insights Dashboard.
This dashboard is meant to provide the users with breakdown of their EKS clusters in-cluster costs, in a single-pane-of-glass with their other dashboards.

## Architecture

The following is the solution's architecture:

![Screenshot of the solution's architecture](./screenshots/kubecost_cid_architecture.png)

The solution deploys the following resources:

1. Data collection Pod (deployed using a CronJob controller) and Service Account in your EKS cluster
2. The following AWS resources:<br />
IAM Role for Service Account<br />
AWS Glue Database<br />
AWS Glue Table<br />
AWS Glue Crawler (along with its IAM Role and IAM Policy)

High-level logic:

1. The CronJob runs daily and creates a Pod that collects cost allocation data from Kubecost. It runs the following API calls:<br />
The [Allocation API on-demand query (experimental)](https://docs.kubecost.com/apis/apis/allocation#querying-on-demand-experimental) to retrieve the cost allocation data.<br />
The [Assets API](https://docs.kubecost.com/apis/apis/assets-api) to retrieve the assets data.<br />
It always collects the data between 72 hours ago 00:00:00 and 48 hours ago 00:00:00.<br />
2. Once data is collected, it's then converted to a Parquet, compressed and uploaded to an S3 bucket of your choice. This is when the CronJob finishes<br />
3. The data is made available in Athena using AWS Glue. In addition, a AWS Glue Crawler runs daily, 1 hour after the CronJob started, to create or update partitions
4. QuickSight uses the Athena table as a data source to visualize the data

## Requirements

### High-level Requirements

 1. An EKS cluster, and an [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)
 2. Kubecost (free tier is enough) deployed in the EKS cluster
 3. An S3 bucket
 4. QuickSight Enterprise with CID deployed
 5. The `cid-cmd` tool ([install with PIP](https://pypi.org/project/cid-cmd/))
 6. Terraform

Please continue reading the specific requirements sections “S3 Bucket”, “Configure Athena Query Results Location” and “Configure QuickSight Permissions”. 

### S3 Bucket

As a preliminary requirement, an S3 bucket must be created in account where you’ll deploy the QuickSight dashboard (see step 3 in the "High-level Requirements" section above).
You may create an S3 Bucket Policy, and in this case, make sure to allow the principals being used by the data collection pod to execute the `PutOject` action. 

### Configure Athena Query Results Location

To set the Athena Query Results Location, follow both steps below.

#### Step 1: Set Query Results Location in the Athena Query Editor

Navigate to Athena Console -> Query Editor -> Settings:
![Screenshot of Athena Query Editor Settings View](./screenshots/athena_query_editor_view_settings.png)

If the "Query result location" field is empty, click "Manage", set the Query result location, and save:
![Screenshot of Athena Query Editor Settings Edit](./screenshots/athena_query_editor_manage_settings.png)

#### Step 2: Set Query Results Location in the Athena Workgroup Settings

Navigate to Athena Console -> Administration -> Workgroups:
![Screenshot of Athena Workgroups Page](./screenshots/athena_workgroups_page.png)

Click on the relevant Workgroup, and you'll see the Workgroup settings:
![Screenshot of Athena Workgroups Settings View](./screenshots/athena_workgroup_settings_view.png)

If the "Query result location" field is empty, go back to the Workgroups page, and edit the Workgroup settings:
![Screenshot of Athena Workgroups Page Edit Workgroup](./screenshots/athena_workgroups_page_edit_workgroup.png)

In the settings page, set the Query results location, and save:
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
3. Add the S3 bucket in the same sections of the policy where you have your CUR bucket. Example:
    `"arn:aws:s3:::kubecost-data*"`


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

#### Provide Terraform Inputs

Edit `terraform/terraform_aws_helm_resources/locals.tf` and provide at least the required inputs.<br />
The below table lists the required and optional inputs from the `locals.tf` file:

| Input | Default | Description | Supported Values
|--|--|--|--|
| region (required) |  | The AWS region to deploy the resources (it doesn't have to be the same region as the EKS cluster | AWS Region code (for example, `us-east-1` |
| eks_iam_oidc_provider_arn (required) |  | The EKS IAM OIDC Provider ARN.<br />Retrieve by navigating to IAM console -> Access management -> Identity providers -> click on the provider for the EKS cluster -> copy the value of "ARN" |  |
| bucket_arn (required) |  | the ARN of the bucket to which the Parquet files will be written |  |
| image (required) |  | The registry, repository and tag to pull (`<registry_url>/<repo>:<tag>`) |  |
| cluster_arn (required) |  | Your EKS cluster ARN |  |
| k8s_config_path | `~/.kube/config` | Full path of the K8s config file |  |
| k8s_namespace | `kubecost-s3-exporter` | The namespace to use for the data collection pod |  |
| k8s_service_account | `kubecost-s3-exporter` | The K8s service account name |  |
| k8s_create_namespace | `true` | Specifies whether to create the namespace | `true`, `false` |
| image_pull_policy | `Always` | Specifies the image pull policy | `Always`, `IfNotPresent`, `Never` |
| schedule | `0 0 * * *` | Cron schedule (in UTC) | Any Cron schedule |
| kubecost_api_endpoint | `http://kubecost-cost-analyzer.kubecost:9090` | The Kubecost API endpoint URL and port | `http://<host>:<port>` |
| granularity | `hourly` | The granularity of the collected data | `hourly`, `daily` |
| k8s_labels | `[]` | A list of labels (as strings) to include in the Parquet | For example: `["app", "chart"]` |

Notes:

1. The `region` specifies where to create the AWS resources for the data collection pod. It doesn't have to be the same as the region where the EKS cluster is
2. Cron always runs in UTC, so the `schedule` input is in UTC. For example, if you specify `0 0 * * *` (daily at 00:00:00am), and you're in GMT +2, the CronJob will run daily at 02:00:00am and not daily at 00:00:00am

#### Apply the Terraform Template

From `terraform/terraform_aws_helm_resources`, run `terraform apply`.<br />
It'll deploy both the AWS resources, and invoke Helm to deploy the CronJob and Service Account.

### Step 3: Dashboard Deployment

#### Deploy the Dashboard from the CID YAML File

From the `cid` folder, run `cid-cmd deploy --resources eks_insights_<version>.yaml`.<br />
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
     » athenacurcfn_udid_cur1
       kubecost_db
       spectrumdb

From the list, choose the Athena database that was created by the Terraform template.<br />
If you didn't change the AWS Glue Database name in the Terraform template, then it'll be `kubecost_db` - please choose it.
After choosing, wait for the dataset to be created, and then the additional output should be similar to the below:

    ? [athena-database] Select AWS Athena database to use: kubecost_db
    Dataset "eks_insights" created
    Latest template: arn:aws:quicksight:us-east-1:<account_id>:template/eks_insights/version/1
    Deploying dashboard eks_insights
    
    #######
    ####### Congratulations!
    ####### EKS Insights is available at: https://us-east-1.quicksight.aws.amazon.com/sn/dashboards/eks_insights
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
5. Navigate back to “Datasets” on the main QuickSight menus on the left, click the eks_insights dataset, and verify that the refresh status shows as “Completed”.<br />
Once it is - the dashboard is ready to be used, and you can navigate to “Dashboards”, click the EKS Insights dashboard, and start using the dashboard.

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

## Cleanup

### QuickSight Cleanup

1. Delete any analysis you created from the dashboard
2. Delete the dashboard
3. Delete the dataset

### AWS and K8s Resources Cleanup

1. From `terraform/terraform_aws_helm_resources`, run `terraform destroy`.<br />
It'll remove both the AWS resources, and invoke Helm to remove the CronJob and Service Account.
2. Manually remove the CloudWatch Log Stream that was created by the AWS Glue Crawler
3. Empty and delete the S3 bucket you created
4. Run `kubectl delete ns <namespace>` to remove the K8s namespace
