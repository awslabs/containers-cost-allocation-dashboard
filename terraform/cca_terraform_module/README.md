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

* Manage your AWS credentials using [shared configuration and credentials files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).   
This is required because this Terraform module is meant to create or access resources in different AWS accounts that may require different sets of credentials.
* In your kubeconfig file, each EKS cluster should reference the AWS profile from the shared configuration file.  
This is so that Helm (invoked by Terraform or manually) can tell which AWS credentials to use when communicating with the cluster.

## Structure

Below is the complete module structure, followed by details on each directory/module:

    cca_terraform_module/
    ├── README.md
    ├── deploy
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── providers.tf
    ├── examples
    │   ├── deploy
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── providers.tf
    │   └── modules
    │       └── common
    │           ├── locals.tf
    │           ├── outputs.tf
    │           └── variables.tf
    └── modules
        ├── common
        │   ├── README.md
        │   ├── locals.tf
        │   ├── outputs.tf
        │   └── variables.tf
        ├── kubecost_s3_exporter
        │   ├── README.md
        │   ├── kubecost_s3_exporter.tf
        │   ├── locals.tf
        │   ├── outputs.tf
        │   └── variables.tf
        ├── pipeline
        │   ├── README.md
        │   ├── locals.tf
        │   ├── outputs.tf
        │   ├── pipeline.tf
        │   ├── secret_policy.tpl
        │   └── variables.tf
        └── quicksight
            ├── README.md
            ├── locals.tf
            ├── quicksight.tf
            ├── timezones.txt
            └── variables.tf

### The `modules` Directory

The `modules` directory contains the reusable Terraform child modules used to deploy the solution.  
It contains several modules, as follows:

#### The `common` Module

The `common` reusable module in the `common` directory only has variables and outputs.  
It contains the common variables that are used by other modules.

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

It contains module-specific variables, and resources.  
It also contains a `timezones.txt` file you can use to choose time zone when setting dataset refresh schedule.

### The `deploy` Directory

The `deploy` directory is the root module.  
It contains the `main.tf` file used to call the child reusable modules and deploy the resources.  
Use this file to add calling modules that call:
* The `pipline` reusable module that deploy the pipeline resources
* The `kubecost_s3_exporter` reusable module for each cluster, to deploy the Kubecost S3 Exporter on your clusters
* The `quicksight` reusable module  

This directory also has the `providers.tf` file, where you add a provider configuration for each module.  
Lastly, this directory has an `outputs.tf` file, to be used to add your required outputs.

### The `examples` Directory

The `examples` directory includes examples of the following files:  

* Examples of the `main.tf`, `outputs.tf` and `providers.tf` files from the `deploy` directory
* Examples of the `locals.tf`, `variables.tf` and `outputs.tf` files from the `modules/common` directory

These files give some useful examples for you to get started when modifying the actual files.

## Initial Deployment

Deployment of the Kubecost CID solution using this Terraform module requires the following steps:

1. Provide common inputs in the `common` module in the `variables.tf` file
2. Add provider configuration for each module, in the `providers.tf` file in the root module
3. Provide module-specific inputs in the `main.tf` file in the root module, for:
   1. The `pipeline` reusable module
   2. The `kubecost-s3-exporter` reusable module for each cluster
   3. The `quicksight` reusable module
4. Optionally, add outputs to the `outputs.tf` file in the root module 
5. Deploy

### Step 1: Provide Common Inputs

The deployment of this solution involves both AWS resources deployment and a data collection pod (Kubecost S3 Exporter) deployment.  
Both have some common inputs, and to make things easy, the `common` module is provided for this purpose.  
Usually in a Terraform module, variables values are given in each calling module in the root module, but it's not the case with the `common` module.   
The `common` module's variables values must be given in the module's [`variables.tf`](modules/common/variables.tf) file, and not in the `main.tf` file.  
They're given using the `default` keyword in the variable definition itself.  
This is to not repeat these inputs twice for each module in the `main.tf` file.

See the [`commmon` module README.md file](modules/common/README.md) for a list of required and optional variables.  
Open the `common` module's [`variables.tf`](modules/common/variables.tf) file and provide the inputs.  
Currently, the only required variable is the `bucket_arn`.

### Step 2: Define Providers in the `providers.tf` File

After providing common inputs, we need to define providers in the [`providers.tf`](deploy/providers.tf) file in the root module.  
In this file you'll define providers for:

* The `pipeline` module, to identify the AWS account where the pipeline AWS resources will be created
* The `kubecost_s3_exporter` module, to identify the clusters and AWS accounts where the Kubecost S3 Exporter will be deployed
* The `quicksight` module, to identify the AWS account where the QuickSight resources will be created

These providers include references to credential files that will be used by Terraform when creating resources.

#### Define Provider for the `pipeline` Module

In the [`providers.tf`](deploy/providers.tf) file in the `deploy` directory, you'll find a pre-created `aws` provider for the `pipeline` module:

    provider "aws" {
    
      # This is an example, to help you get started
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "pipeline_profile"
      default_tags {
        tags = module.common.aws_common_tags
      }
    }


* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the pipeline resources 

Examples can be found in the [`examples/deploy/providers.tf`](examples/deploy/providers.tf) file.

#### Define Provider for each EKS Cluster for the `kubecost_s3_exporter` Module

In the [`providers.tf`](deploy/providers.tf) file in the `deploy` directory, you'll find 3 pre-created providers for a sample cluster.  
The first 2 are for a cluster with Helm invocation, and the last one is for cluster without Helm invocation:

    # Example providers for cluster with Helm invocation
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster1"
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "profile1"
      default_tags {
        tags = module.common.aws_common_tags
      }
    }
    
    provider "helm" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster1"
    
      kubernetes {
        config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
        config_path    = "~/.kube/config"
      }
    }
    
    # Example providers for cluster without Helm invocation
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster2"
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "profile1"
      default_tags {
        tags = module.common.aws_common_tags
      }
    }

In the `aws` provider:

* Change the `alias` field to a unique name that represents your EKS cluster.  
It must be unique among the `aws` provider definitions.
* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to communicate with the cluster

If you decided to have Terraform invoke Helm (the default behavior), you also need the `helm` provider. Otherwise, you don't need it.  
In case you decided to have Terraform invoke Helm, here's what you need to change in the `helm` provider:

* Change the `alias` field to a unique name that represents your EKS cluster.    
It can be the same alias as in the corresponding `aws` provider for the same cluster.  
It must be unique among the `helm` provider definitions.
* Change the `kubernetes.config_context` to the config context of your cluster.  
To identify the cluster context, you can execute `kubectl config get-contexts`, `kubectl config view` or `cat <kubeconfig file path>`.  
More information on contexts can be found in [this document](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#context).
* Change the `kubernetes.config_path` to the path of your kube config file, if needed

Repeat the `aws` provider definition for each account-region combination where you'd like to deploy the Kubecost S3 Exporter on a cluster.  
Repeat the `helm` provider definition for each cluster on which you'd like to deploy the Kubecost S3 Exporter.  
Make sure that each provider's alias is unique per provider type.

#### Define Provider for the `quicksight` Module

In the [`providers.tf`](deploy/providers.tf) file in the `deploy` directory, you'll find a pre-created `aws` provider for the `quicksight` module:

    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "quicksight"
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "quicksight_profile"
      default_tags {
        tags = module.common.aws_common_tags
      }
    }


* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the QuickSight resources 

### Step 3: Call Reusable Modules and Provide Module-Specific Inputs in the `main.tf` File

After defining the providers, we need to provide module-specific inputs in the [`main.tf`](deploy/main.tf) file in the root module.    
In this file you'll create a calling module for:

* The `pipeline` module
* The `kubecost_s3_exporter` module, per cluster
* The `quicksight` module

You'll provide the module-specific inputs in these calling modules.

#### Create a Calling Module for the `pipeline` Module and Provide Module-Specific Inputs


In the `main.tf` file in the `deploy` directory, you'll find a pre-created `pipeline` calling module:

    module "pipeline" {
      source = "../modules/pipeline"
    }

The `pipeline` module doesn't have any required variables, but it has optional variables.  
See the [`pipline` module README.md file](modules/pipeline/README.md) for a list of variables.  
If you don't need to change one of the optional variables, you can leave the pre-created calling module as is.

#### Create a Calling Module for the `kubecost_s3_exporter` Module and Provide Module-Specific Inputs

In the `main.tf` file in the `deploy` directory, you'll find 2 pre-created `kubecost-s3-exporter` calling modules.  
The first one is for a cluster with Helm invocation, and the last one is for a cluster without Helm invocation:

    # Example module instance for cluster with Helm invocation
    module "cluster1" {
    
      # This is an example, to help you get started
    
      source = "../modules/kubecost_s3_exporter"
    
      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster1
        helm         = helm.us-east-1-111111111111-cluster1
      }
    
      cluster_arn                          = ""
      kubecost_s3_exporter_container_image = ""
    }
    
    # Example module instance for cluster without Helm invocation
    module "cluster2" {
    
      # This is an example, to help you get started
    
      source = "../modules/kubecost_s3_exporter"
    
      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster2
      }
    
      cluster_arn                          = ""
      kubecost_s3_exporter_container_image = ""

Change the name of the calling module from "cluster1" to a name that uniquely represents your cluster.  
It doesn't have to be the same name as the provider alias you defined for the cluster, but using consistent naming convention is advised.  

Then, provide the module-specific required inputs.  
See the [`kubecost_s3_exporter` module README.md file](modules/kubecost_s3_exporter/README.md) for a list of variables.
Example (more examples can be found in the [`examples/deploy/main.tf` file](examples/deploy/main.tf)):

    module "cluster1" {
      source = "../modules/kubecost_s3_exporter"

      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster1
        helm         = helm.us-east-1-111111111111-cluster1
      }
    
      cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
    }

There are 2 required inputs:
* The `cluster_arn` variable, where you must input the EKS cluster ARN
* The `kubecost_s3_exporter_container_image`, where you must input the Kubecost S3 Exporter Docker image.
That's the image you built and pushed in "Step 2: Build and Push the Container Image" in the DEPLOYMENT.md file.

Optionally, change module-specific optional inputs, if needed.

Finally, after providing the inputs, change the providers references in the `providers` block:

1. Always leave the `aws.pipeline` field as is.  
It references the pipeline provider, and is used by the `kubecost_s3_exporter` reusable module to create the parent IAM role in the pipeline account
2. Change the `aws.eks` field value to the alias of the `aws` provider.  
This must be the alias of the `aws` provider you defined for this cluster in the `providers.tf` file
3. If this cluster is deployed using Helm invocation, change the `helm` field value to the alias of the `helm` provider.  
This must be the alias of the `helm` provider you defined in the `providers.tf` file for this cluster.  
Otherwise, the `helm` field isn't necessary in this calling module.

Create such a calling module for each cluster on which you wish to deploy the Kubecost S3 Exporter pod.  
Make sure that each calling module has a unique name (`module "<unique_name>"`).

**_Notes:_**

1. The `tls_verify` and `kubecost_ca_certificate_secret_name` are used for TLS connection to Kubecost.  
If you didn't enable TLS in Kubecost, they aren't relevant, and you can ignore this input for this cluster.  
If you enabled TLS in Kubecost, then `tls_verify` will be used by the Kubecost S3 Exporter container to verify the Kubecost server certificate.  
In this case, you must provide the CA certificate in the `kubecost_ca_certificates_list`, and specify the secret name for it in the `kubecost_ca_certificate_secret_name` input.  
If you don't do so, and `tls_verify` is set, the TLS connection will fail.  
Otherwise, you can unset the `tls_verify` input. The connection will still be encrypted, but it's less secure due to the absence of server certificate verification.
2. If you defined a secret name in `kubecost_ca_certificate_secret_name`, you MUST add the `depends_on = [module.pipeline.kubecost_ca_cert_secret]` line in the module instance.  
Thi is due to the following process that happens in Terraform when specifying the above input:  
Terraform will pull the configuration of the secret that was created by the `pipeline` module.  
This is to then use the secret's ARN in the parent IAM role's inline policy, and to use its region in the Python script to get the secret value.  
For this process (Terraform pulling the secret configuration) to work, there must be a dependency between the `kubecost_s3_exporter` module that pulls the secret configuration, and the `pipeline` module that created the secret.  
If the `depends_on = [module.pipeline.kubecost_ca_cert_secret]` line isn't added in this case, the deployment fails.

#### Create a Calling Module for the `quicksight` Module and Provide Module-Specific Inputs

In the `main.tf` file in the `deploy` directory, you'll find a pre-created `quicksight` calling module:

    module "quicksight" {
      source = "../modules/quicksight"
    
      providers = {
        aws = aws.quicksight
      }
    
      glue_database_name = module.pipeline.glue_database_name
      glue_view_name     = module.pipeline.glue_view_name
    
      # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
      # Otherwise, remove the below field
      athena_workgroup_configuration = {
        query_results_location_bucket_name = ""
      }
    }

Provide the module-specific required inputs.  
The only required variable is the `query_results_location_bucket_name` field in the `athena_workgroup_configuration` variable.  
It's prepared for you as can be seen above, with an empty string.  
Notice the comment above it, and act accordingly (fill it out or remove it)

See the [`quicksight` module README.md file](modules/quicksight/README.md) for a list of the module's variables.
Example (more examples can be found in the [`examples/deploy/main.tf` file](examples/deploy/main.tf)):

### Step 4: Optionally, Add Outputs to the `outputs.tf` File

The `deploy` directory has an `outputs.tf` file, used to show useful outputs after deployment.  
Below are explanations on how to use it.

#### The `labels` and `annotations` Outputs

During the deployment, you may add labels or annotations to the dataset for each cluster.  
When doing so, Terraform calculates the distinct labels and annotations from all clusters.  
This is done so that Terraform can create a column in the Glue Table, for each distinct label and annotation.  
This output is included, so that you can make sure the labels and annotations were added to the QuickSight dataset.

The `main.tf` file already has `labels` and `annotations` outputs, to show the list of distinct labels and annotations:

    output "labels" {
      value       = length(module.common.k8s_labels) > 0 ? join(", ", distinct(module.common.k8s_labels)) : null
      description = "A list of the distinct labels of all clusters, that'll be added to the dataset"
    }

    output "annotations" {
      value       = length(module.common.k8s_annotations) > 0 ? join(", ", distinct(module.common.k8s_annotations)) : null
      description = "A list of the distinct annotations of all clusters, that'll be added to the dataset"
    }

No need to make any changes to it.

#### Adding Cluster Outputs for each Cluster

This Terraform module creates an IRSA IAM Role and parent IAM Role for each cluster, as part of the `kubecost-s3-exporter` module.  
It creates them with a name that includes the IAM OIDC Provider ID.  
This is done to keep the IAM Role name within the length limit, but it also causes difficulties in correlating it to a cluster.  
You can add an output to the `output.tf` file for each cluster, to show the mapping of the cluster name and the IAM Roles (IRSA and parent) ARNs.

The `outputs.tf` file already has a sample output to get you started:

    output "cluster1" {
      value       = module.cluster1
      description = "The outputs for 'cluster1'"
    }

Change the output name from `cluster1` to a name that uniquely represents your cluster.  
Then, change the value to reference to the module instance of your cluster (`module.<module_instance_name>`).
More examples can be found in the [`examples/deploy/outputs.tf` file](examples/deploy/outputs.tf).

It is highly advised that you add an output to the `outputs.tf` file for each cluster, to show the IAM Roles ARNs.  
Make sure you use a unique cluster name in the output name.

When deploying, Terraform will output a line showing the output name and the IAM Roles ARNs.

### Step 5: Deploy

From the `deploy` directory, perform the following:

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
3. Create additional calling modules of the `kubecost_s3_exporter` reusable module, for each cluster, and provide inputs.  
This is done in the `main.tf` file in the `deploy` directory.
4. If you need to add labels or annotations for this cluster, follow the [Maintenance -> Adding/Removing Labels/Annotations to/from the Dataset section](#addingremoving-labelsannotations-tofrom-the-dataset)
5. Optionally, add cluster output for the IRSA (IAM Role for Service Account) and parent IAM role, for each cluster

Then, from the `deploy` directory, run `terraform init` and `terraform apply`

### Updating Clusters Inputs

After the initial deployment, you might want to change parameters.  
Below are instructions for doing so:

#### Updating Inputs for Existing Clusters

To update inputs for existing clusters (all or some), perform the following:

1. In the `deploy` directory, open the `main.tf` file
2. Change the relevant inputs in the calling modules of the clusters you wish to update
3. From the `deploy` directory, run `terraform apply`

### Adding/Removing Labels/Annotations to/from the Dataset

After the initial deployment, you might want to add or remove labels or annotations for some or all clusters, to/from the dataset.  
To do this, perform the following:

1. From the `modules/common` directory, open the `variables.tf` file
2. In the `k8s_labels` variable, add the K8s labels keys that you want to include in the dataset.  
This list should include all K8s labels from all clusters, that you wish to include in the dataset.  
Do the same for `k8s_annotations`, if you want to include annotations in the dataset as well.  
As an example, see the below table, showing a possible list of labels and annotations for different clusters:

| Cluster                             | Labels     | Labels Wanted in the Dataset | Annotations  | Annotations Wanted in the Dataset |
|-------------------------------------|------------|------------------------------|--------------|-----------------------------------|
| <a name="cluster_a"></a> cluster\_a | a, b, c, d | a, b, c                      | 1, 2, 3, 4   | 1, 2, 3                           |
| <a name="cluster_b"></a> cluster\_b | a, f, g, h | f, g                         | 1, 6, 7, 8   | 5, 6                              |
| <a name="cluster_c"></a> cluster\_c | x, y, z, a |                              | 9, 10, 11, 1 |                                   |

In this case, this is how the `k8s_labels` and `k8s_annotations` variables will look like:

    variable "k8s_labels" {
      description = "K8s labels common across all clusters, that you wish to include in the dataset"
      type        = list(string)
      default     = ["a", "b", "c", "f", "g"]
    }
    
    variable "k8s_annotations" {
      description = "K8s annotations common across all clusters, that you wish to include in the dataset"
      type        = list(string)
      default     = ["1", "2", "3", "5", "6"]
    }

3. From the `deploy` directory, run `terraform apply`.  
Terraform will output the new list of labels and annotations when the deployment is completed.

**_Note about annotations:_**

While K8s labels are included by default in Kubecost Allocation API response, K8s annotations aren't.  
To include K8s annotations in the Kubecost Allocation API response, following [this document](https://docs.kubecost.com/install-and-configure/advanced-configuration/annotations).

## Cleanup

### Removing Kubecost S3 Exporter from Specific Clusters

To remove the Kubecost S3 Exporter from a specific cluster, perform the following:

1. From the `main.tf` file in the `deploy` directory, remove the module instance of the cluster
2. From the `outputs.tf` file in the `deploy` directory, remove the outputs of the cluster, if any
3. Run `terraform apply`
4. From the `providers.tf` file in the `deploy` directory, remove the providers of the cluster  
You must remove the providers only after you did step 1-3 above, otherwise the above steps will fail
5. If Kubecost S3 Exporter was deployed on this cluster using `invoke_helm=false`:  
You also need to uninstall the chart as follows:  



    helm uninstall kubecost-s3-exporter -n <namespace> --kube-context <cluster_context>

### Complete Cleanup

To completely clean up the entire setup, run `terraform destroy` from the `deploy` directory.  
Then, follow the "Cleanup" section of the main README.md to clean up other resources that weren't created by Terraform.