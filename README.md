
# EKS Insights Dashboard

This is an integration of Kubecost with AWS CID (Cloud Intelligence Dashboards) to create the EKS Insights Dashboard.<br />
This dashboard is meant to provide the users with breakdown of their EKS clusters in-cluster costs, in a single-pane-of-glass with their other dashboards.

## Architecture

The following is the solution's architecture:

![Screenshot of the solution's architecture](./screenshots/kubecost_cid_architecture.png)

The solution deploys the following resources:

1. Data collection Pod (deployed using a CronJob controller) and Service Account in your EKS cluster.<br />
It's referred to as Kubecost S3 Exporter throughout the documentation.
2. The following AWS resources:<br />
IAM Role for Service Account for each cluster<br />
AWS Glue Database<br />
AWS Glue Table<br />
AWS Glue Crawler (along with its IAM Role and IAM Policy)

High-level logic:

1. The CronJob runs daily and creates a Pod that collects cost allocation data from Kubecost. It runs the following API calls:<br />
The [Allocation API on-demand query (experimental)](https://docs.kubecost.com/apis/apis/allocation#querying-on-demand-experimental) to retrieve the cost allocation data.<br />
The [Assets API](https://docs.kubecost.com/apis/apis/assets-api) to retrieve the assets' data.<br />
It always collects the data between 72 hours ago 00:00:00 and 48 hours ago 00:00:00.<br />
2. Once data is collected, it's then converted to a Parquet, compressed and uploaded to an S3 bucket of your choice. This is when the CronJob finishes<br />
3. The data is made available in Athena using AWS Glue. In addition, an AWS Glue Crawler runs daily, 1 hour after the CronJob started, to create or update partitions
4. QuickSight uses the Athena table as a data source to visualize the data

## Requirements

1. An S3 bucket, which will be used to store the Kubecost data
2. QuickSight Enterprise with CID deployed
3. Terraform and Helm installed 
4. The `cid-cmd` tool ([install with PIP](https://pypi.org/project/cid-cmd/)) installed

For each EKS cluster, have the following

1. An [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).<br />
In case your EKS cluster is in a different account than your S3 bucket, you must create the IAM OIDC Provider in the account where the S3 bucket is.<br />
This is mandatory for cross-account authentication.
2. Kubecost (free tier is enough) deployed in the EKS cluster

Please continue reading the specific sections “S3 Bucket Specific Notes”, “Configure Athena Query Results Location” and “Configure QuickSight Permissions”. 

### S3 Bucket Specific Notes

You may create an S3 Bucket Policy on the bucket that you create to store the Kubecost data.<br />
In this case, below is a recommended bucket policy to use.<br />
This bucket policy, along with the identity-based policies of all the identities in this solution, provides minimum access:

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
                    "StringNotLike": {
                        "aws:PrincipalArn": [
                            "arn:aws:iam::333333333333:role/<your_management_role>",
                            "arn:aws:iam::333333333333:role/kubecost_glue_crawler_role",
                            "arn:aws:iam::333333333333:role/service-role/aws-quicksight-service-role-v0"
                        ],
                        "aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"
                    }
                },
                "Bool": {
                    "aws:SecureTransport": "false"
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
* The `aws:PrincipalTag/irsa-kubecost-s3-exporter": "true` condition:<br />
This condition identifies all the EKS clusters on which the Kubecost S3 Exporter pod will be deployed.<br />
When Terraform creates the IRSA (IAM Role for Service Account) for each cluster, for the Kubecost S3 Exporter service account, it tags them the above tag.<br />
This tag is automatically being used in the IAM session when the Kubecost S3 Exporter pod authenticates.<br />
The reason for using this tag is to easily allow all EKS clusters with the Kubecost S3 Exporter pod in the bucket policy, without reaching the bucket policy size limit.<br />
The other alternative is to specify the federated principals that represent each cluster one-by-one.<br />
With this approach, the maximum bucket policy size will be quickly reached, and that's why the tag is used.

The resources used in this S3 bucket policy include:

* The bucket name, to allow access to it
* All objects in the bucket, using the `arn:aws:s3:::kubecost-data-collection-bucket/*` string.<br />
The reason for using a wildcard here is that multiple principals (multiple EKS clusters) require access to different objects in the bucket.<br />
Using specific objects for each principal will result in a longer bucket policy that'll eventually exceed the bucket policy size limit.<br />
the identity policy (IRSA) that is created as part of this solution for each cluster, specifies only the specific prefix and objects.<br >
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
The Terraform module deploys the AWS resources, and invokes Helm to deploy the K8s resources.<br />
Please follow the instructions under `terraform/kubecost_cid_terraform_module/README.md`.<br />
For the initial deployment, you need to go through the "Requirements", "Structure" and "Initial Deployment" sections.<br />
Once you're done, continue to step 3 below.

### Step 3: Dashboard Deployment

#### Adding Labels

If as part of the Terraform deployment, you added labels in the `clusters_labels` input, those labels need to be added to the dashboard YAML .<br />
If you didn't add labels in the `clusters_labels` input, you can skip this part.

To easily get the list of distinct labels that were added, copy them from the Terraform outputs.<br />
Below are example output labels that Terraform should show after apply:<br />

    Outputs:
    
    labels = "app, chart, component"

Please follow the below steps add those labels to the dashboard YAML:<br />

Open the `cid/eks_insights_<version>.yaml`, and modify it as follows:<br />
Look or the following lines:<br />

            - Name: properties.providerid
              Type: STRING
            - Name: account_id
              Type: STRING

Between these lines, add the following line for each label:

            - Name: properties.labels.<label_name>
              Type: STRING

For example, for the above output labels, the YAML should look like the below after adding the lines:

            - Name: properties.providerid
              Type: STRING
            - Name: properties.labels.app
              Type: STRING
            - Name: properties.labels.chart
              Type: STRING
            - Name: properties.labels.component
              Type: STRING
            - Name: account_id
              Type: STRING

Save the file and continue to the next step.

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
     » <cur_db>
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
4. Run `kubectl delete ns <namespace>` to remove the K8s namespace
