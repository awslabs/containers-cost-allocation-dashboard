# Deployment

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
With this option, Terraform will create a cluster-specific `values.yaml` file (with a unique name) for each cluster, which you can use

You can use a mix of these options.  
On some clusters, you can choose to deploy the K8s resources by having Terraform invoke Helm (the first option).  
On other clusters, you can choose to deploy the K8s resources yourself using the `helm` command (the second option).

### Deployment Option 1

With this deployment option, Terraform deploys both the AWS resources and the K8s resources (by invoking Helm).

1. Open the [`providers.tf`](terraform/cca_terraform_module/providers.tf) file and define the providers.  
Follow the sections and the comments in the file, which provide instructions.
2. Open the [`main.tf`](terraform/cca_terraform_module/main.tf) file and define the calling modules.  
Follow the sections and the comments in the file, which provide instructions.
3. Run `terraform init`
4. Run `terraform apply`

If you want more detailed information, please follow the instructions in the [Terraform module README](terraform/cca_terraform_module/README.md) file.  
For the initial deployment, you need to go through the [Requirements](terraform/cca_terraform_module/README.md/.#requirements), [Structure](terraform/cca_terraform_module/README.md/.#structure) and [Initial Deployment](terraform/cca_terraform_module/README.md/.#initial-deployment) sections.  

Once you're done with Terraform, continue to [step 3](#step-3-dashboard-deployment) below.

### Deployment Option 2

With this deployment option, Terraform deploys only the AWS resources, and the K8s resources are deployed using the `helm` command.

1. Open the [`providers.tf`](terraform/cca_terraform_module/providers.tf) file and define the providers.  
Follow the sections and the comments in the file, which provide instructions.
2. Open the [`main.tf`](terraform/cca_terraform_module/main.tf) file and define the calling modules.  
Follow the sections and the comments in the file, which provide instructions.  
Make sure you use `invole_helm` input set to `false` in each cluster's calling module.
3. Run `terraform init`
4. Run `terraform apply`

After applying the Terraform configuration, a YAML file will be created per cluster, containing the Helm values for this cluster.  
The YAML file for each cluster will be named `<cluster_account_id>_<cluster_region>_<cluster_name>_values.yaml`.  
The YAML files will be created in the `helm/kubecost_s3_exporter/clusters_values` directory.  
Then, for each cluster, deploy the K8s resources by executing Helm.  
Executing Helm when you're still in the Terraform `deploy` directory:

    helm upgrade -i kubecost-s3-exporter ../../../helm/kubecost_s3_exporter/ -n <namespace> --values ../../../helm/kubecost_s3_exporter/clusters_values/<cluster>.yaml --create-namespace --kube-context <cluster_context>

Executing Helm when in the `helm` directory:

    helm upgrade -i kubecost-s3-exporter kubecost_s3_exporter/ -n <namespace> --values kubecost_s3_exporter/clusters_values/<cluster>.yaml --create-namespace --kube-context <cluster_context>

If you want more detailed information, please follow the instructions in the [Terraform module README](terraform/cca_terraform_module/README.md) file.  
For the initial deployment, you need to go through the [Requirements](terraform/cca_terraform_module/README.md/.#requirements), [Structure](terraform/cca_terraform_module/README.md/.#structure) and [Initial Deployment](terraform/cca_terraform_module/README.md/.#initial-deployment) sections.

Once you're done, continue to [step 3](#step-3-dashboard-deployment) below.

## Step 3: Dashboard Deployment

As part of using Terraform to create the AWS resources, it also created a `cca.yaml` file.  
This file is used to deploy the QuickSight dashboard.  
From the `cid` folder, run the following command:

    cid-cmd deploy --resources cca.yaml --dashboard-id containers-cost-allocation-cca  

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
    
    Latest template: arn:aws:quicksight:us-east-1:829389350341:template/containers-cost-allocation-cca/version/<latest_version>
    Dashboard "containers-cost-allocation-cca" is not deployed
    
    Required datasets:
     - <data_set_name>
    
    
    Looking by DataSetId defined in template...
        Found <data_set_name> as <data_set_id>
    complete
    Using dataset <data_set_name>: <data_set_id>
    Deploying dashboard containers-cost-allocation-cca
    
    #######
    ####### Congratulations!
    ####### Containers Cost Allocation (CCA) is available at: https://<data_set_id>.quicksight.aws.amazon.com/sn/dashboards/containers-cost-allocation-cca
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

Note:  
Data won't be available in the dashboard at least until the first time the data collection pod runs and collects data.
You must have data from at lest 72 hours ago in Kubecost for the data collection pod to collect data.