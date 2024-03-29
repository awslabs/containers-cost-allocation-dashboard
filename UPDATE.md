# Update the Solution

## Updates to the Kubecost S3 Exporter

The following are considered updates to the Kubecost S3 Exporter:

* Updates to the Kubecost S3 Exporter Python script
* Updates to the Python dependencies of the Kubecost S3 Exporter Python script
* Updates to the content of the `Dockerfile`

When any of the above is changed, follow the below steps to perform an update:

1. Build and push the Docker image.  
You can follow the same steps as in [Step 1: Build and Push the Container Image in the `DEPLOYMENT.md` file](DEPLOYMENT.md/.#step-1-build-and-push-the-container-image).
2. Depending on how you deployed the K8s resources, choose one of the below:
   1. If you used [Deployment Option 1](DEPLOYMENT.md/.#deployment-option-1):  
      Run `terraform apply` on the Terraform module, from the root directory of the Terraform module.
   2. If you used [Deployment Option 2](DEPLOYMENT.md/.#deployment-option-2):
      Run `helm upgrade` on the new Helm chart.

## Updates to the Helm Chart

In case of updates to the Helm chart only, run `helm upgrade`

## Updates to Resources Created by the Terraform Module

In case of updates to resources created by the Terraform module:  
Running `terraform apply` will detect the changes, show you what's changed, and then you can apply the changes. 

## Updates to the Dashboard

Note for users who customized the dashboard:  
Make sure to keep a copy of the customized dashboard, update the original one, and merge with your customizations.

In case of a new dashboard version, run the following command from the `cid` folder:

    cid-cmd update --resources containers_cost_allocation.yaml --dashboard-id containers-cost-allocation

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
    
    Latest template: arn:aws:quicksight:us-east-1:223485597511:template/containers-cost-allocation/version/2
    An update is available:
                  Deployed -> Latest
      Version    v0.3.2      v0.3.3
      VersionId  1           2
    Using dataset cca_kubecost_view: 53076fa4-4238-a2e1-8672-3909f0621986
    
    Checking for updates...
    Deployed template: arn:aws:quicksight:us-east-1:223485597511:template/containers-cost-allocation/version/1
    Latest template: arn:aws:quicksight:us-east-1:223485597511:template/containers-cost-allocation/version/2
    
    Updating containers-cost-allocation
    Update completed
    
    #######
    ####### Containers Cost Allocation (CCA) is available at: https://<region>.quicksight.aws.amazon.com/sn/dashboards/containers-cost-allocation
    #######

If there's no updated version of the dashboard, that output should be similar to the below:

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
    You are up to date!
      Version    v0.3.2
      VersionId  1
    Using dataset cca_kubecost_view: 53076fa4-4238-a2e1-8672-3909f0621986
    
    Checking for updates...
    Deployed template: arn:aws:quicksight:us-east-1:223485597511:template/containers-cost-allocation/version/1
    Latest template: arn:aws:quicksight:us-east-1:223485597511:template/containers-cost-allocation/version/1
    
    ? [confirm-update] No updates available, should I update it anyway?: (Use arrow keys)
     » yes
       no

Select "no", and upon selection, you should see output similar to the below:

    ? [confirm-update] No updates available, should I update it anyway?: no

If you need to force update, select "yes", and you should see an output similar to the below:

    ? [confirm-update] No updates available, should I update it anyway?: yes
    
    Updating containers-cost-allocation
    Update completed
    
    #######
    ####### Containers Cost Allocation (CCA) is available at: https://eu-north-1.quicksight.aws.amazon.com/sn/dashboards/containers-cost-allocation
    #######
