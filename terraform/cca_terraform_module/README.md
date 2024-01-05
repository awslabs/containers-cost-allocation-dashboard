# Containers Cost Allocation (CCA) Dashboard Terraform Module

This Terraform Module is used to deploy the resources required for the Containers Cost Allocation (CCA) dashboard.  
It's suitable to deploy the resources in multi-account, multi-region, multi-cluster environments.  
It's used to deploy the following:

1. The AWS resources that support the solution
2. The K8s resources (Kubecost S3 Exporter CronJob and Service Account) on each cluster.  
This is done either by invoking Helm, or by generating a Helm `values.yaml` for you to deploy.  
These options are configurable per cluster by using the `invoke_helm` variable.  
If set, Terraform will invoke Helm and will deploy the K8s resources This is the default option.  
If not set, Terraform will generate a Helm `values.yaml` for this cluster.  
You'll then need to deploy the K8s resources yourself using the `helm` command.

This guide is composed of the following sections:

1. Requirements:  
A list of the requirements to use this module.
2. Structure:  
Shows the module's structure.
3. Initial Deployment:  
Provides initial deployment instructions.
4. Maintenance:  
Provides information on common changes that might be done after the initial deployment.
5. Cleanup:  
Provides information on the process to clean up resources.

## Requirements

This Terraform module requires the following:

* That you completed all requirements in the [REQUIREMENTS.md](../../REQUIREMENTS.md) file
* Manage your AWS credentials using [shared configuration and credentials files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).   
This is required because this Terraform module is meant to create or access resources in different AWS accounts that may require different sets of credentials.
* In your kubeconfig file, each EKS cluster should reference the AWS profile from the shared configuration file.  
This is so that Helm (invoked by Terraform or manually) can tell which AWS credentials to use when communicating with the cluster.

## Structure

Below is the complete module structure, followed by details on each directory/module:

    cca_terraform_module/
    ├── README.md
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── timezones.txt
    ├── examples
    │   └── root_module
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── providers.tf
    └── modules
        ├── common_locals
        │   ├── locals.tf
        │   └── outputs.tf
        ├── common_variables
        │   ├── README.md
        │   ├── outputs.tf
        │   └── variables.tf
        ├── kubecost_s3_exporter
        │   ├── README.md
        │   ├── locals.tf
        │   ├── main.tf
        │   ├── outputs.tf
        │   └── variables.tf
        ├── pipeline
        │   ├── README.md
        │   ├── locals.tf
        │   ├── main.tf
        │   ├── outputs.tf
        │   ├── secret_policy.tpl
        │   └── variables.tf
        └── quicksight
            ├── README.md
            ├── locals.tf
            ├── main.tf
            └── variables.tf

### The Root Directory

The root directory the root module.  
It contains the [`main.tf`](main.tf) file used to call the child reusable modules and deploy the resources.  
Use this file to add calling modules that call:
* The `common_variables` reusable module, that is usd to provide common variables to all other modules
* The `pipline` reusable module that deploy the pipeline resources
* The `kubecost_s3_exporter` reusable module for each cluster, to deploy the Kubecost S3 Exporter on your clusters
* The `quicksight` reusable module  

This directory also has the following files:

* The [`providers.tf`](providers.tf) file, where you add a provider configuration for each module  
* The [`outputs.tf`](outputs.tf) file, to be used to add your required outputs
* The [`timezones.txt`](timezones.txt) file you can use to choose time zone when setting dataset refresh schedule

### The `modules` Directory

The `modules` directory contains the reusable Terraform child modules used to deploy the solution.  
It contains several modules, as follows:

#### The `common_locals` Module

The `common_locals` reusable module in the `common_locals` directory only has locals and outputs.  
It contains the common locals that are used by other modules. It does not contain resources.

#### The `common_variables` Module

The `common_variables` reusable module in the `common_variables` directory only has variables and outputs.  
It contains the common variables that are used by other modules. It does not contain resources.

#### The `pipeline` Module

The `pipeline` reusable module in the `pipeline` directory contains the Terraform IaC required to deploy the AWS pipeline resources.  
It contains module-specific variables, outputs, and resources.  
It also contains a template file (secret_policy.tpl) that contains IAM policy for AWS Secrets Manager secret policy.

#### The `kubecost_s3_exporter` Module

The `kubecost_s3_exporter` reusable module in the `kubecost_s3_exporter` directory contains the Terraform IaC required to deploy:

* The K8s resources (the CronJob used to create the Kubecost S3 Exporter pod, and a service account) on each EKS cluster
* For each EKS cluster:
  * The IRSA (IAM Role for Service Account) in the EKS cluster's account
  * If the cluster is in different account than the S3 bucket, also a parent IAM role is created, in the S3 bucket's account 

It contains module-specific variables, outputs, and resources.

#### The `quicksight` Module

The `quicksight` reusable module in the `quicksight` directory contains the Terraform IaC required to deploy:

* The Athena workgroup
* The QuickSight data source and dataset
* Generate YAML file used to create the QuickSight dashboard

It contains module-specific variables, and resources

### The `examples` Directory

The `examples` directory currently includes only the `root_module` directory.  
It includes examples of the [`main.tf`](examples/root_module/main.tf), [`outputs.tf`](examples/root_module/outputs.tf) and [`providers.tf`](examples/root_module/providers.tf) files from the root directory (root module)  
These files give some useful examples for you to get started when modifying the actual files.

## Initial Deployment

Deployment of the Containers Cost Allocation (CCA) Dashboard using this Terraform module requires the following steps:

1. Add provider configuration for each reusable module, in the [`providers.tf`](providers.tf) file in the root module
   1. Add provider for the `pipeline` reusable module
      See the [module's README.md file](modules/pipeline/README.md) for more information and examples.
   2. Add provider for the `kubecost_s3_exporter` reusable module
      See the [module's README.md file](modules/kubecost_s3_exporter/README.md) for more information and examples.
   3. Add provider for the `quicksight` reusable module
      See the [module's README.md file](modules/quicksight/README.md) for more information and examples.
2. Provide variables values in the [`main.tf`](main.tf) file in the root module, for:
   1. The `common_variables` reusable module.  
      See the [module's README.md file](modules/common_variables/README.md) for more information and examples.
   2. The `pipeline` reusable module
      See the [module's README.md file](modules/pipeline/README.md) for more information and examples.
   3. The `kubecost_s3_exporter` reusable module for each cluster
      See the [module's README.md file](modules/kubecost_s3_exporter/README.md) for more information and examples.
   4. The `quicksight` reusable module
      See the [module's README.md file](modules/quicksight/README.md) for more information and examples.
3. Optionally, add outputs to the [`outputs.tf`](outputs.tf) file in the root module
   1. See more information on the `common_variables` module's outputs in the [module's README.md file](modules/common_variables/README.md)
   2. See more information on the `kubecost_s3_exporter` module's outputs in the [module's README.md file](modules/kubecost_s3_exporter/README.md)
4. Deploy:  
   From the root directory of the Terraform module:
   1. Run `terraform init`
   2. Run `terraform apply`

## Maintenance

After the solution is initially deployed, you might want to make changes.  
Below are instruction for some common changes that you might do after the initial deployment. 

### Deploying on Additional Clusters

When adding additional clusters after the initial deployment, not all the initial deployment steps are required.  
To continue adding additional clusters after the initial deployment, the only required steps are as follows, for each cluster:

1. Create an [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) in the EKS cluster's account
2. Define additional providers for the clusters
3. Create additional calling modules of the `kubecost_s3_exporter` reusable module, for each cluster, and provide variables values.  
This is done in the [`main.tf`](main.tf) file in the root directory.  
You can follow the instructions in the [`kubecost_s3_exporter` calling module creation steps](modules/kubecost_s3_exporter/README.md/.#create-a-calling-module-for-the-kubecosts3exporter-module-and-provide-variables-values)
4. If you need to add labels or annotations for this cluster, follow the [Maintenance -> Adding/Removing Labels/Annotations to/from the Dataset section](#addingremoving-labelsannotations-tofrom-the-dataset)
5. Optionally, add cluster output for the IRSA (IAM Role for Service Account) and parent IAM role, for each cluster

Then, from the root directory, run `terraform init` and `terraform apply`

### Updating Clusters Inputs

After the initial deployment, you might want to change parameters.  
Below are instructions for doing so:

#### Updating Inputs for Existing Clusters

To update inputs for existing clusters (all or some), perform the following:

1. In the root directory, open the [`main.tf`](main.tf) file
2. Change the relevant inputs in the calling modules of the clusters you wish to update
3. From the root directory, run `terraform apply`

### Adding/Removing Labels/Annotations to/from the Dataset

After the initial deployment, you might want to add or remove labels or annotations for some or all clusters, to/from the dataset.  
To do this, perform the following in the `common_variables` calling module in the [`main.tf`](main.tf) file in the root directory:
1. To add labels, add the K8s labels keys in the `k8s_labels` variable.  
This list should include all K8s labels from all clusters, that you wish to include in the dataset.  
2. To add annotations, add the K8s annotations keys in the `k8s_annotations` variable.  
This list should include all K8s annotations from all clusters, that you wish to include in the dataset. 

As an example, see the below table, showing a possible list of labels and annotations for different clusters:

| Cluster                             | Labels     | Labels Wanted in the Dataset | Annotations  | Annotations Wanted in the Dataset |
|-------------------------------------|------------|------------------------------|--------------|-----------------------------------|
| <a name="cluster_a"></a> cluster\_a | a, b, c, d | a, b, c                      | 1, 2, 3, 4   | 1, 2, 3                           |
| <a name="cluster_b"></a> cluster\_b | a, f, g, h | f, g                         | 1, 6, 7, 8   | 5, 6                              |
| <a name="cluster_c"></a> cluster\_c | x, y, z, a |                              | 9, 10, 11, 1 |                                   |

In this case, this is how the `k8s_labels` and `k8s_annotations` variables will look like:

    ################################
    # Section 1 - Common Variables #
    ################################
    
    # Calling module for the common module, to provide common variables values
    # These variables are then used in other modules
    module "common_variables" {
      source = "./modules/common_variables"
    
      bucket_arn      = "<bucket_arn_here>" # Add S3 bucket ARN here, of the bucket that will be used to store the data collected from Kubecost
      k8s_labels      = ["a", "b", "c", "f", "g"] # Optionally, add K8s labels you'd like to be present in the dataset
      k8s_annotations = ["1", "2", "3", "5", "6"] # Optionally, add K8s annotations you'd like to be present in the dataset
      aws_common_tags = {} # Optionally, add AWS common tags you'd like to be created on all resources
    }

3. From the root directory, run `terraform apply`.  
Terraform will output the new list of labels and annotations when the deployment is completed.

**_Note about annotations:_**

While K8s labels are included by default in Kubecost Allocation API response, K8s annotations aren't.  
To include K8s annotations in the Kubecost Allocation API response, following [this document](https://docs.kubecost.com/install-and-configure/advanced-configuration/annotations).

## Cleanup

### Removing Kubecost S3 Exporter from Specific Clusters

To remove the Kubecost S3 Exporter from a specific cluster, perform the following:

1. From the [`main.tf`](main.tf) file in the root directory, remove the calling module instance of the cluster
2. From the [`outputs.tf`](outputs.tf) file in the root directory, remove the outputs of the cluster, if any
3. Run `terraform apply`
4. From the [`providers.tf`](providers.tf) file in the root directory, remove the providers of the cluster  
You must remove the providers only after you did step 1-3 above, otherwise the above steps will fail
5. If Kubecost S3 Exporter was deployed on this cluster using `invoke_helm=false`, you also need to uninstall the chart:  
`helm uninstall kubecost-s3-exporter -n <namespace> --kube-context <cluster_context>`

### Complete Cleanup

To completely clean up the entire setup, run `terraform destroy` from the root directory.  
Then, follow the "Cleanup" section of the main README.md to clean up other resources that weren't created by Terraform.