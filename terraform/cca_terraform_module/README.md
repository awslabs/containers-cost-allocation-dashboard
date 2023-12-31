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
    ├── deploy_local
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── terraform.tfstate
    │   ├── terraform.tfstate.backup
    │   └── timezones.txt
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

1. Add provider configuration for each module, in the [`providers.tf`](providers.tf) file in the root module
2. Provide variables values in the [`main.tf`](main.tf) file in the root module, for:
   1. The `common_variables` module
   2. The `pipeline` reusable module
   3. The `kubecost-s3-exporter` reusable module for each cluster
   4. The `quicksight` reusable module
3. Optionally, add outputs to the [`outputs.tf`](outputs.tf) file in the root module 
4. Deploy

### Step 1: Define Providers in the `providers.tf` File

After providing common inputs, we need to define providers in the [`providers.tf`](providers.tf) file in the root module.  
In this file you'll define providers for:

* The `pipeline` module, to identify the AWS account where the pipeline AWS resources will be created
* The `kubecost_s3_exporter` module, to identify the clusters and AWS accounts where the Kubecost S3 Exporter will be deployed
* The `quicksight` module, to identify the AWS account where the QuickSight resources will be created

These providers include references to credential files that will be used by Terraform when creating resources.

#### Define Provider for the `pipeline` Module

In the [`providers.tf`](providers.tf) file in the root directory, you'll find a pre-created `aws` provider for the `pipeline` module:

    #####################################
    # Section 1 - Pipeline AWS Provider #
    #####################################
    
    # Example provider for the pipeline
    provider "aws" {
    
      # This is an example, to help you get started
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "pipeline_profile"
      default_tags {
        tags = module.common_variables.aws_common_tags
      }
    }

* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the pipeline resources 

Examples can be found in the [`examples/root_module/providers.tf`](examples/root_module/providers.tf) file.

#### Define Provider for each EKS Cluster for the `kubecost_s3_exporter` Module

In the [`providers.tf`](providers.tf) file in the root directory, you'll find 3 pre-created providers for a sample cluster.  
The first 2 are for a cluster with Helm invocation, and the last one is for cluster without Helm invocation:

    ###########################################################
    # Section 2 - Kubecost S3 Exporter AWS and Helm Providers #
    ###########################################################
    
    #                                                    #
    # Example providers for cluster with Helm invocation #
    #                                                    #
    
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster1"
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "profile1"
      default_tags {
        tags = module.common_variables.aws_common_tags
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
    
    #                                                       #
    # Example provider for cluster without Helm invocation  #
    #                                                       #
    
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster2"
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "profile1"
      default_tags {
        tags = module.common_variables.aws_common_tags
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

Examples can be found in the [`examples/root_module/providers.tf`](examples/root_module/providers.tf) file.

#### Define Provider for the `quicksight` Module

In the [`providers.tf`](providers.tf) file in the root directory, you'll find a pre-created `aws` provider for the `quicksight` module:

    #######################################
    # Section 3 - Quicksight AWS Provider #
    #######################################
    
    # Example provider for QuickSight
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "quicksight"
    
      region                   = "us-east-1"
      shared_config_files      = ["~/.aws/config"]
      shared_credentials_files = ["~/.aws/credentials"]
      profile                  = "quicksight_profile"
      default_tags {
        tags = module.common_variables.aws_common_tags
      }
    }

* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the QuickSight resources 

Examples can be found in the [`examples/root_module/providers.tf`](examples/root_module/providers.tf) file.

### Step 2: Provide Variable Values for Each Module

After defining the providers, we need to provide module-specific variables values in the [`main.tf`](main.tf) file in the root module.    
In this file you'll create a calling module for:

* The `common_variables` module
* The `pipeline` module
* The `kubecost_s3_exporter` module, per cluster
* The `quicksight` module

You'll provide the variables values in these calling modules.

#### Create a Calling Module for the `common_variables` Module and Provide Variables Values

The deployment of this solution involves both AWS resources deployment and a data collection pod (Kubecost S3 Exporter) deployment.  
Both have common variables, and to make things easy, the `common_variables` module is provided for this purpose.

In the [`main.tf`](main.tf) file in the root directory, you'll find a pre-created `common_variables` calling module:

    ################################
    # Section 1 - Common Variables #
    ################################
    
    # Calling module for the common module, to provide common variables values
    # These variables are then used in other modules
    module "common_variables" {
      source = "./modules/common_variables"
    
      bucket_arn      = "" # Add S3 bucket ARN here, of the bucket that will be used to store the data collected from Kubecost
      k8s_labels      = [] # Optionally, add K8s labels you'd like to be present in the dataset
      k8s_annotations = [] # Optionally, add K8s annotations you'd like to be present in the dataset
      aws_common_tags = {} # Optionally, add AWS common tags you'd like to be created on all resources
    }

All variables are already present in the pre-created calling module, with empty values.  
The only required variable is the `bucket_arn`, please provide a value.  
You can also optionally provide values for the other variables, if needed.  

For more information on the variables, see the [`commmon_variables` module README.md file](modules/common_variables/README.md).  
For examples, see the [`examples/root_module/main.tf` file](examples/root_module/main.tf).

#### Create a Calling Module for the `pipeline` Module and Provide Variables Values

In the [`main.tf`](main.tf) file in the root directory, you'll find a pre-created `pipeline` calling module:

    ######################################
    # Section 2 - AWS Pipeline Resources #
    ######################################
    
    # Calling module for the pipeline module, to create the AWS pipeline resources
    module "pipeline" {
      source = "./modules/pipeline"
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module, do not remove
    
      bucket_arn      = module.common_variables.bucket_arn
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                           #
      # Pipeline Module Variables #
      #                           #
    
      # Provide optional pipeline module variables values here, if needed
    
    }

##### Provide Variables Values

Variables referenced from the `common_variables` module are already present, please do not change or remove them.  
The `pipeline` module's own variables are all optional.  
If you don't need to change one of the optional variables, you can leave the pre-created calling module as is.  

For more information on the variables, see the [`pipline` module README.md file](modules/pipeline/README.md).  
For examples, see the [`examples/root_module/main.tf` file](examples/root_module/main.tf).

#### Create a Calling Module for the `kubecost_s3_exporter` Module and Provide Variables Values

In the [`main.tf`](main.tf) file in the root directory, you'll find 2 pre-created `kubecost-s3-exporter` calling modules.  
The first one is for a cluster with Helm invocation, and the last one is for a cluster without Helm invocation:

    #########################################################
    # Section 3 - Data Collection Pod Deployment using Helm #
    #########################################################
    
    # Calling modules for the kubecost_s3_exporter module, to create IRSA and deploy the K8s resources
    
    # Example calling module for cluster with Helm invocation
    module "cluster1" {
    
      # This is an example, to help you get started
    
      source = "./modules/kubecost_s3_exporter"
    
      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster1
        helm         = helm.us-east-1-111111111111-cluster1
      }
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module
      # Always include when creating new calling module, and do not remove
    
      bucket_arn      = module.common_variables.bucket_arn
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = ""
      kubecost_s3_exporter_container_image = ""
    }
    
    # Example calling module for cluster without Helm invocation
    module "cluster2" {
    
      # This is an example, to help you get started
    
      source = "./modules/kubecost_s3_exporter"
    
      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster2
      }
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module
      # Always include when creating new calling module, and do not remove
    
      bucket_arn      = module.common_variables.bucket_arn
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = ""
      kubecost_s3_exporter_container_image = ""
      invoke_helm                          = false
    }

##### Rename the Calling Module 

Rename of the calling module from "cluster1" to a name that uniquely represents your cluster.  
It doesn't have to be the same name as the provider alias you defined for the cluster, but using consistent naming convention is advised.  

##### Change Providers References

Change the providers references in the `providers` block:

1. Always leave the `aws.pipeline` field as is.  
It references the pipeline provider, and is used by the `kubecost_s3_exporter` reusable module to create the parent IAM role in the pipeline account
2. Change the `aws.eks` field value to the alias of the `aws` provider.  
This must be the alias of the `aws` provider you defined for this cluster in the `providers.tf` file
3. If this cluster is deployed using Helm invocation, change the `helm` field value to the alias of the `helm` provider.  
This must be the alias of the `helm` provider you defined in the `providers.tf` file for this cluster.  
Otherwise, the `helm` field isn't necessary in this calling module.

##### Provide Variables Values

Variables referenced from the `common_variables` module are already present, please do not change or remove them.  
The `kubecost_s3_exporter` module has 2 required variables:
* The `cluster_arn` variable, where you must input the EKS cluster ARN
* The `kubecost_s3_exporter_container_image`, where you must input the Kubecost S3 Exporter Docker image.
That's the image you built and pushed in ["Step 2: Build and Push the Container Image" in the DEPLOYMENT.md file](../../DEPLOYMENT.md/.#step-1-build-and-push-the-container-image).

Example:

    module "cluster1" {
      source = "./modules/kubecost_s3_exporter"

      ... omitted output ...

      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
    }

If you're deploying this module without Helm invocation ["Deployment Option 2" in the DEPLOYMENT.md file](../../DEPLOYMENT.md/.#deployment-option-2):  
Make sure the `invoke_helm` has value of `false`, as below:

    module "cluster2" {
      source = "./modules/kubecost_s3_exporter"

      ... omitted output ...

      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
      kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
      invoke_helm                          = false
    }

Provide optional variables values if needed.

For more information on the variables, see the [`kubecost_s3_exporter` module README.md file](modules/kubecost_s3_exporter/README.md).  
For examples, see the [`examples/root_module/main.tf` file](examples/root_module/main.tf).

###### Notes

1. The `tls_verify` and `kubecost_ca_certificate_secret_name` are used for TLS connection to Kubecost.  
If you didn't enable TLS in Kubecost, they aren't relevant, and you can ignore this input for this cluster.  
If you enabled TLS in Kubecost, then `tls_verify` will be used by the Kubecost S3 Exporter container to verify the Kubecost server certificate.  
In this case, you must provide the CA certificate in the `kubecost_ca_certificates_list`, and specify the secret name for it in the `kubecost_ca_certificate_secret_name` input.  
If you don't do so, and `tls_verify` is set, the TLS connection will fail.  
Otherwise, you can unset the `tls_verify` input. The connection will still be encrypted, but it's less secure due to the absence of server certificate verification.
2. If you defined a secret name in `kubecost_ca_certificate_secret_name`, you MUST add the `kubecost_ca_certificate_secrets` variable with value of `module.pipeline.kubecost_ca_cert_secret` in the calling module.  
Thi is due to the following process that happens in Terraform when specifying the above variable:  
Terraform will pull the configuration of the secret that was created by the `pipeline` module.  
This is to then use the secret's ARN in the parent IAM role's inline policy, and to use its region in the Python script to get the secret value.  
For this process (Terraform pulling the secret configuration) to work, the following must happen:  
There must be a dependency between the `kubecost_s3_exporter` module that pulls the secret configuration, and the `pipeline` module that created the secret.  
If the `kubecost_ca_certificate_secrets` variable with value of `module.pipeline.kubecost_ca_cert_secret` isn't added in this case, the deployment fails.

##### Deploy on Additional Clusters

Repeat the above steps for this calling module, for each cluster on which you wish to deploy the Kubecost S3 Exporter.  
Make sure that each calling module has a unique name (`module "<unique_name>"`).

#### Create a Calling Module for the `quicksight` Module and Provide Variables Values

In the [`main.tf`](main.tf) file in the root directory, you'll find a pre-created `quicksight` calling module:

    ####################################
    # Section 4 - Quicksight Resources #
    ####################################
    
    # Calling module for the quicksight module, to create the QuickSight resources
    module "quicksight" {
      source = "./modules/quicksight"
    
      providers = {
        aws = aws.quicksight
      }
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module, do not remove
    
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                           #
      # Pipeline Module Variables #
      #                           #
    
      # References to variables outputs from the pipeline module, do not remove
    
      glue_database_name = module.pipeline.glue_database_name
      glue_view_name     = module.pipeline.glue_view_name
    
      #                             #
      # QuickSight Module Variables #
      #                             #
    
      # Provide quicksight module variables values here
    
      # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
      # Otherwise, remove the below field
      athena_workgroup_configuration = {
        query_results_location_bucket_name = ""
      }
    }

##### Provide Variables Values

Variables referenced from the `common_variables` module are already present, please do not change or remove them.  
The `quicksight` module has one required variable:
The `query_results_location_bucket_name` field in the `athena_workgroup_configuration` variable.  
It's prepared for you as can be seen above, with an empty string.  
Notice the comment above it, and act accordingly (provide value or remove it)

For more information on the variables, see the [`quicksight` module README.md file](modules/quicksight/README.md).  
For examples, see the [`examples/root_module/main.tf` file](examples/root_module/main.tf).

### Step 3: Optionally, Add Outputs to the `outputs.tf` File

The root directory has an [`outputs.tf`](outputs.tf) file, used to show useful outputs after deployment.  
Below are explanations on how to use it.

#### The `labels` and `annotations` Outputs

During the deployment, you may add labels or annotations to the dataset for each cluster.  
When doing so, Terraform calculates the distinct labels and annotations from all clusters.  
This is done so that Terraform can create a column in the Glue Table, for each distinct label and annotation.  
This output is included, so that you can make sure the labels and annotations were added to the QuickSight dataset.

The [`outputs.tf`](outputs.tf) file already has `labels` and `annotations` outputs, to show the list of distinct labels and annotations:

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
You can add an output to the [`output.tf`](outputs.tf) file for each cluster, to show the mapping of the cluster name and the IAM Roles (IRSA and parent) ARNs.

The `outputs.tf` file already has a sample output to get you started:

    output "cluster1" {
      value       = module.cluster1
      description = "The outputs for 'cluster1'"
    }

Change the output name from `cluster1` to a name that uniquely represents your cluster.  
Then, change the value to reference to the module instance of your cluster (`module.<module_instance_name>`).
More examples can be found in the [`examples/root_module/outputs.tf` file](examples/root_module/outputs.tf).

It is highly advised that you add an output to the `outputs.tf` file for each cluster, to show the IAM Roles ARNs.  
Make sure you use a unique cluster name in the output name.

When deploying, Terraform will output a line showing the output name and the IAM Roles ARNs.

### Step 4: Deploy

From the root directory, perform the following:

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
You can follow the instructions in the [`kubecost_s3_exporter` calling module creation steps](#create-a-calling-module-for-the-kubecost_s3_exporter-module-and-provide-variables-values)
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