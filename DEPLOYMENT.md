# Deployment

Clone the repo:

    git clone https://github.com/awslabs/containers-cost-allocation-dashboard.git

There are 3 high-level steps to deploy the solution:

1. [Build and Push the Container Image](#step-1-build-and-push-the-container-image)
2. [Deploy the AWS and K8s Resources](#step-2-deploy-the-aws-and-k8s-resources)
3. [Dashboard Deployment](#step-3-dashboard-deployment)

## Step 1: Build and Push the Container Image

We do not provide a public image, so you'll need to build an image and push it to the registry and repository of your choice.  
For the registry, we recommend using Private Repository in Amazon Elastic Container Registry (ECR).  
You can find instructions on creating a Private Repository in ECR in [this document](https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html), and pricing information can be found [here](https://aws.amazon.com/ecr/pricing/).  
The name for the repository can be any name you'd like - for example, you can use `kubecost-s3-exporter`.  
If you decided to use Private Repository in ECR, you'll have to configure your Docker client to log in to it first, before pushing the image to it.  
You can find instructions on logging in to a Private Repository in ECR using Docker client, in [this document](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html).  

Note for the image build process:  
You might want to build for a target platform which is different from the source machine.  
In this case, make sure you use [QEMU emulation](https://docs.docker.com/build/building/multi-platform/#qemu).  
Please note that currently, the `Dockerfile` can be used to build images for `amd64` and `arm64` architectures.

In this section, choose either [Build and Push for a Single Platform](#build-and-push-for-a-single-platform) or [Build and Push for Multiple Platforms](#build-and-push-for-multiple-platforms).

### Build and Push for a Single Platform

Build for a platform as the source machine:

    docker build -t <registry_url>/<repo>:<tag> .

Build for a specific target platform:

    docker build --platform linux/amd64 -t <registry_url>/<repo>:<tag> .

Push:

    docker push <registry_url>/<repo>:<tag>

### Build and Push for Multiple Platforms

    docker buildx build --push --platform linux/amd64,linux/arm64/v8 --tag <registry_url>/<repo>:<tag> .

## Step 2: Deploy the AWS and K8s Resources

This solution provides a Terraform module for deployment of both the AWS the K8s resources.  
There are 2 options to use it:
* Deployment Option 1: Deploy both the AWS resources and the K8s resources using Terraform (K8s resources are deployed by invoking Helm)
* Deployment Option 2: Deploy only the AWS resources using Terraform, and deploy the K8s resources using the `helm` command.  
With this option, Terraform will create a cluster-specific `values.yaml` file (with a unique name) for each cluster, which you can use.

You can use a mix of these options.  
On some clusters, you can choose to deploy the K8s resources by having Terraform invoke Helm (the first option).  
On other clusters, you can choose to deploy the K8s resources yourself using the `helm` command (the second option).

### Deployment Option 1

With this deployment option, Terraform deploys both the AWS resources and the K8s resources (by invoking Helm).

1. Open the [`providers.tf`](terraform/terraform-aws-cca/providers.tf) file and define the providers.  
Follow the sections and the comments in the file, which provide instructions.
2. Open the [`terraform.tfvars`](terraform/terraform-aws-cca/terraform.tfvars) file and provide common root module variable values.  
Follow the comments in the file, which provide instructions.
3. Open the [`main.tf`](terraform/terraform-aws-cca/main.tf) file and define the calling modules.  
Follow the sections and the comments in the file, which provide instructions.
4. Run `terraform init`
5. Run `terraform apply`

If you want more detailed information, please follow the instructions in the [Terraform module README file](terraform/terraform-aws-cca/README.md).  
For the initial deployment, you need to go through the [Requirements](terraform/terraform-aws-cca/README.md/.#requirements), [Structure](terraform/terraform-aws-cca/README.md/.#structure) and [Initial Deployment](terraform/terraform-aws-cca/README.md/.#initial-deployment) sections.  

Once you're done with Terraform, continue to [step 3](#step-3-dashboard-deployment) below.

### Deployment Option 2

With this deployment option, Terraform deploys only the AWS resources, and the K8s resources are deployed using the `helm` command.

1. Open the [`providers.tf`](terraform/terraform-aws-cca/providers.tf) file and define the providers.  
Follow the sections and the comments in the file, which provide instructions.
2. Open the [`terraform.tfvars`](terraform/terraform-aws-cca/terraform.tfvars) file and provide common root module variable values.  
Follow the comments in the file, which provide instructions.
3. Open the [`main.tf`](terraform/terraform-aws-cca/main.tf) file and define the calling modules.  
Follow the sections and the comments in the file, which provide instructions.  
Make sure you use `invole_helm` input set to `false` in each cluster's calling module.
4. Run `terraform init`
5. Run `terraform apply`

If you want more detailed information, please follow the instructions in the [Terraform module README file](terraform/terraform-aws-cca/README.md).  
For the initial deployment, you need to go through the [Requirements](terraform/terraform-aws-cca/README.md/.#requirements), [Structure](terraform/terraform-aws-cca/README.md/.#structure) and [Initial Deployment](terraform/terraform-aws-cca/README.md/.#initial-deployment) sections.

After applying the Terraform configuration, a YAML file will be created per cluster, containing the Helm values for this cluster.  
The YAML file for each cluster will be named `<cluster_account_id>_<cluster_region>_<cluster_name>_values.yaml`.  
The YAML files will be created in the `helm/kubecost_s3_exporter/clusters_values` directory.  
Then, for each cluster, deploy the K8s resources by executing Helm.  
Executing Helm when you're still in the Terraform module root directory:

    helm upgrade -i kubecost-s3-exporter ../../helm/kubecost_s3_exporter/ -n <namespace> --values ../../../helm/kubecost_s3_exporter/clusters_values/<cluster>.yaml --create-namespace --kube-context <cluster_context>

Executing Helm when in the `helm` directory:

    helm upgrade -i kubecost-s3-exporter kubecost_s3_exporter/ -n <namespace> --values kubecost_s3_exporter/clusters_values/<cluster>.yaml --create-namespace --kube-context <cluster_context>

Once you're done, continue to [step 3](#step-3-dashboard-deployment) below.

## Step 3: Dashboard Deployment

Follow all subsections below to deploy the dashboard and be able to use it.

### Deploy the QuickSight Assets

From the `cid` folder, run the following command:

    cid-cmd deploy --resources containers_cost_allocation.yaml --dashboard-id containers-cost-allocation --athena-database kubecost_db --quicksight-datasource-id cca --athena-workgroup primary --timezone <timezone>

Replace `<timezone>` with a timezone from the lists in the [timezones.txt file](timezones.txt) in the project's root directory.  
You can also remove the `--timezone` argument, and the CLI tool will present timezones list for you.  
Make sure you provide credentials as environment variables or by passing `--profile_name` argument to the above command.  
Make sure you provide region as environment variable or by passing `--region_name` argument to the above command.  
The output after executing the above command, should be similar to the below:

    CLOUD INTELLIGENCE DASHBOARDS (CID) CLI 0.2.39 Beta
    
    Loading plugins...
        Core loaded
    
    
    Checking AWS environment...
        profile name: <profile_name>
        accountId: <acocunt_id>
        AWS userId: <user_id>
        Region: <region>
    
    
    Discovering deployed dashboards...  [####################################]  100%  "KPI Dashboard" (kpi_dashboard)
    
    Latest template: arn:aws:quicksight:us-east-1:223485597511:template/containers-cost-allocation/version/1
    Dashboard "containers-cost-allocation" is not deployed
    
    Required datasets:
     - cca_kubecost_view
    
    
    Looking by DataSetId defined in template...complete
    
    There are still 1 datasets missing: cca_kubecost_view
    Creating dataset: cca_kubecost_view
    Detected views: kubecost_view
    Dataset "cca_kubecost_view" created
    Using dataset cca_kubecost_view: 53076fa4-4238-a2e1-8672-3909f0621986
    Deploying dashboard containers-cost-allocation
    
    #######
    ####### Congratulations!
    ####### Containers Cost Allocation (CCA) is available at: https://<region>.quicksight.aws.amazon.com/sn/dashboards/containers-cost-allocation
    #######
    
    ? [share-with-account] Share this dashboard with everyone in the account?: (Use arrow keys)
     » yes
       no

Choose whether to share the dashboard with everyone in this account.  
Selecting "yes" will result in an output similar to the below:

    ? [share-with-account] Share this dashboard with everyone in the account?: yes
    Sharing complete

Selecting "no" will result in an output similar to the below:

    ? [share-with-account] Share this dashboard with everyone in the account?: no

Any of the above selections will complete the deployment.

### What Needs to Happen for Data to Appear on the Dashboard?

Before you start using the dashboard, make sure the following is true:

* Data must be present in the S3 bucket.
For this, the Kubecost S3 Exporter container must have collected data for at least one day.  
Note: since it collects data from 72 hours ago 00:00:00 to 48 hours ago 00:00:00, it might find no data on new Kubecost deployments.  
Wait until enough data was collected by Kubecost, so that the Kubecost S3 Exporter can collect data.
* The Glue crawler must have successfully run after data was already uploaded by Kubecost S3 Exporter to the S3 bucket.  
Note that there must not be any files in the S3 bucket, other than the ones uploaded by the Kubecost S3 Exporter.
* The QuickSight dataset must have refreshed successfully after the Glue crawler ran successfully

### Save and Publish the Dashboard

If you added labels to the dataset (using the `k8s_labels` and `k8s_annotations` Terraform variables):  
1. Log in to QuickSight and go to the "Datasets" menu on the left
2. Click the `cca_kubecost_view` dataset, then click "EDIT DATASET"
3. On the top right, click "SAVE & PUBLISH"
4. To monitor the process, click the "QuickSight" icon on the top right.  
Then, go to the "Datasets" menu and click the `cca_kubecost_view` dataset again.
5. Click the "Refresh" tab.  
On the "History" table, you should see the most recent refresh with "Refresh type" column of "Manual, Edit".  
Wait until it's successfully finished, then you can start using the dashboard.
