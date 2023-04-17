
# Kubecost CID Integration Terraform Module

This Terraform Module is used to deploy the resources required for the Kubecost CID integration.<br />
It's suitable to deploy the resources in multi-account, multi-region, multi-cluster environments.<br />
It's used to deploy the following:

1. The AWS resources that support the solution
2. The Kubecost S3 Exporter Pod on each cluster, by invoking Helm

This guide is composed of the following sections:

1. Requirements:<br />
A list of the requirements to use this module.
2. Structure:<br />
Shows the module's structure.
3. Initial Deployment:<br />
Provides initial deployment instructions.
4. Maintenance:<br />
Provides information on common changes that might be done after the initial deployment.
5. Cleanup:<br />
Provides information on the process to clean up resources.

## Requirements

This Terraform module requires the following:

* Manage your AWS credentials using [shared configuration and credentials files](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).<br /> 
This is required because this Terraform module is meant to create or access resources in different AWS accounts that may require different sets of credentials.
* In your kubeconfig file, each EKS cluster should reference the AWS profile from the shared configuration file.<br />
This is so that Helm (invoked by Terraform or manually) can tell which AWS credentials to use when communicating with the cluster.

## Structure

Below is the complete module structure, followed by details on each directory/submodule:

    kubecost_cid_terraform_module/
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
    │           ├── outputs.tf
    │           └── variables.tf
    └── modules
        ├── common
        │   ├── outputs.tf
        │   └── variables.tf
        ├── kubecost_s3_exporter
        │   ├── kubecost_s3_exporter.tf
        │   ├── outputs.tf
        │   └── variables.tf
        └── pipeline
            ├── outputs.tf
            ├── pipeline.tf
            ├── secret_policy.tpl
            └── variables.tf

### The `modules` Directory

The `modules` directory contains the reusable Terraform child modules used to deploy the solution.<br />
It contains several modules, as follows:

#### The `common` Module

The `common` module in the `common` directory only has variables and outputs.<br />
It contains the common inputs that are used by other modules.

#### The `pipeline` Module

The `pipeline` module in the `pipeline` directory contains the Terraform IaC required to deploy the AWS pipeline resources.<br />
It contains module-specific inputs, outputs, and resources.

#### The `kubecost_s3_exporter` Module

The `kubecost_s3_exporter` module in the `kubecost_s3_exporter` directory contains the Terraform IaC required to deploy:

* The K8s resources (the CronJob used to create the Kubecost S3 Exporter pod, and a service account) on each EKS cluster
* For each EKS cluster, the IRSA (IAM Role for Service Account) in the EKS cluster's account, and a parent IAM role (role chaining) in the S3 bucket's account 

It contains module-specific inputs, outputs, and resources.

### The `deploy` Directory

The `deploy` directory is the root module.<br />
It contains the `main.tf` file used to call the child reusable modules and deploy the resources.<br />
Use this file to add module instances that represent the pipline and the clusters on which you want to deploy the Kubecost S3 Exporter pod.<br />
This directory also has the `providers.tf` file, where you add a provider configuration for each module.<br />
Lastly, this directory has an `outputs.tf` file, to be used to add your required outputs, and 

### The `examples` Directory

The `examples` directory includes examples of the following files:<br />

* Examples of the `main.tf`, `outputs.tf` and `providers.tf` files from the `deploy` directory
* Examples of the `variables.tf` and `outputs.tf` files from the `modules/common` directory

These files give some useful examples for you to get started when modifying the actual files.

## Initial Deployment

Deployment of the Kubecost CID solution using this Terraform module requires the following steps:

1. Provide common inputs in the `common` module
2. Add provider configuration for each module, in the `providers.tf` file
3. Provide module-specific inputs for the AWS pipeline resources and for each cluster, in the `main.tf` file
4. Optionally, add outputs to the `main.tf` file 
5. Deploy

### Step 1: Provide Common Inputs

The deployment of this solution involves both AWS resources deployment and a data collection pod (Kubecost S3 Exporter) deployment.<br />
Both have some common inputs, and to make things easy, the `common` module is provided for common inputs.<br />
These inputs must be given in the `variables.tf` file using the `default` keyword, and not in the `main.tf` file.<br />
This is to not repeat these inputs twice in the `main.tf` file.

The below table lists the required and optional common inputs:

| Name                                                                                | Description                                                                                             | Type                                                                                                                                                        | Default                                     | Possible Values                              | Required |
|-------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|----------------------------------------------|----------|
| <a name="input_bucket_arn"></a> bucket\_arn                                         | The ARN of the S3 Bucket to which the Kubecost data will be uploaded                                    | `string`                                                                                                                                                    | `""`                                        | An S3 Bucket ARN                             | yes      |
| <a name="input_clusters_labels"></a> clusters\_labels                               | A list of objects containing clusters and their K8s labels that you wish to include in the dataset      | <pre>list(object({<br>    cluster_id = string<br>    labels = optional(list(string))<br>  }))</pre>                                                         | `[]`                                        |                                              | no       |
| <a name="input_kubecost_ca_certificates_list"></a> kubecost\_ca\_certificates\_list | A list of objects containing CA certificates paths and their desired secret name in AWS Secrets Manager | <pre>list(object({<br>    cert_path = string<br>    cert_secret_name = string<br>    cert_secret_allowed_principals = optional(list(string))<br>  }))</pre> | `[]`                                        |                                              | no       |
| <a name="input_aws_shared_config_files"></a> aws\_shared\_config\_files             | Paths to the AWS shared config files                                                                    | `list(string)`                                                                                                                                              | <pre>[<br>  "~/.aws/config"<br>]</pre>      | A list of paths to the AWS config file       | no       |
| <a name="input_aws_shared_credentials_files"></a> aws\_shared\_credentials\_files   | Paths to the AWS shared credentials files                                                               | `list(string)`                                                                                                                                              | <pre>[<br>  "~/.aws/credentials"<br>]</pre> | A list of paths to the AWS credentials file  | no       |
| <a name="input_aws_common_tags"></a> aws\_common\_tags                              | Common AWS tags to be used on all AWS resources created by Terraform                                    | `map(any)`                                                                                                                                                  | `{}`                                        | A map of tag keys and their values           | no       |
| <a name="input_granularity"></a> granularity                                        | The time granularity of the data that is returned from the Kubecost Allocation API                      | `string`                                                                                                                                                    | `"hourly"`                                  | One of "hourly" or "daily", case-insensitive | no       |

The below table lists the required inputs of the `clusters_labels` input:

| Name                                        | Description                                                                   | Type           | Default | Possible Values              | Required |
|---------------------------------------------|-------------------------------------------------------------------------------|----------------|---------|------------------------------|----------|
| <a name="input_cluster_id"></a> cluster\_id | The unique ID of the cluster that its labels you'd like to add to the dataset | `string`       | n/a     | An EKS Cluster ARN           | yes      |
| <a name="input_labels"></a> labels          | A list of labels to include in the dataset                                    | `list(string)` | n/a     | A list of labels, as strings | no       |

The below table lists the required inputs of the `kubecost_ca_certificates_list` input:

| Name                                                                                  | Description                                                                         | Type           | Default | Possible Values                         | Required |
|---------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|----------------|---------|-----------------------------------------|----------|
| <a name="input_cert_path"></a> cert\_path                                             | Local path (including file name) to the CA certificate file                         | `string`       | n/a     | A path                                  | yes      |
| <a name="input_cert_secret_name"></a> cert\_secret\_name                              | The AWS Secrets Manager secret name to be used for the CA certificate               | `string`       | n/a     | A valid AWS Secrets Manager secret name | yes      |
| <a name="input_cert_secret_allowed_principals"></a> cert\_secret\_allowed\_principals | A list of additional principal ARNs to add to the AWS Secrets Manager secret policy | `list(string)` | n/a     | A list of principal ARNs                | no       |

To provide the inputs, open the `modules/common/variables.tf` file, and perform the following:

#### Provide the Common Required Inputs

Provide the common required inputs, as listed in the above table.<br />
You must provide the values in the `default` keyword of each variable, by changing the default empty value.<br />
See examples in the `examples/modules/common/variables.tf` file.

#### Optionally, Change the Common Optional Inputs

Optionally, if needed, change the default for the common optional inputs.<br />
If you decide to change them, you must provide the value in the `default` keyword.<br />
See examples in the `examples/modules/common/variables.tf` file.

Note - the `clusters_labels` input is a list of clusters and their labels you wish to include in the dataset.<br />
If you don't need to include labels for some clusters, don't include those clusters in the list atl all.<br />
If you don't need to include labels for any cluster, leave the `default` keyword as an empty list (`[]`).

### Step 2: Define Providers in the `providers.tf` File

After providing common inputs, we need to define providers in the `pipeline.tf` file in the root module, that will be used for the deployment.<br />
In this file you'll define a provider for the `pipeline` module, and one or more providers for the `kubecost_s3_exporter` module.<br />
These providers include references to credential files that will be used by Terraform when creating resources.

#### Define Provider for the `pipeline` Module

In the `providers.tf` file in the `deploy` directory, you'll find a pre-created `aws` pipeline provider:

    provider "aws" {
    
      # This is an example, to help you get started
    
      region                   = "us-east-1"
      shared_config_files      = module.common.aws_shared_config_files
      shared_credentials_files = module.common.aws_shared_credentials_files
      profile                  = "pipeline_profile"
      default_tags {
        tags = module.common.aws_common_tags
      }
    }


Change the `region` field if needed.<br />
Also, change the `profile` field to the AWS Profile that Terraform should use to create the pipeline resources. 

#### Define Provider for each EKS Cluster

In the `providers.tf` file in the `deploy` directory, you'll find 3 pre-created providers for a sample cluster.<br />
The first 2 are for a cluster with Helm invocation, and the last one is for cluster without Helm invocation:

    # Example providers for cluster with Helm invocation
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster1"
    
      region                   = "us-east-1"
      shared_config_files      = module.common.aws_shared_config_files
      shared_credentials_files = module.common.aws_shared_credentials_files
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
      shared_config_files      = module.common.aws_shared_config_files
      shared_credentials_files = module.common.aws_shared_credentials_files
      profile                  = "profile1"
      default_tags {
        tags = module.common.aws_common_tags
      }
    }

In the `aws` provider:

1. Change the `alias` field to a unique name that'll represent your EKS cluster.<br />
2. Change the `region` field if needed
3. Change the `profile` field to the AWS Profile that Terraform should use to communicate with the cluster.

If you decided to use "Deployment Option 1" (where Terraform invokes Helm), you also need the `helm` provider.<br />
Otherwise, you don't need it, and it can be removed.<br />
In case you need it, here's what you need to change in it:

1. Change the `alias` field to a unique name that'll represent your EKS cluster.<br />
It can be the same alias as in the corresponding `aws` provider for this cluster.
2. Change the `kubernetes.config_context` to the config context of your cluster
3. Change the `kubernetes.config_path` to the path of your kube config file

Repeat the providers definition for each cluster on which you'd like to deploy the solution.<br />
Make sure that each provider's alias is unique per provider type.

### Step 3: Provide Module-Specific Inputs in the `main.tf` File

After defining the providers, we need to provide module-specific inputs in the `main.tf` file in the root module, that will be used for the deployment.<br />  
In this file you'll create an instance of the `pipeline` module, and one or more instances of the `kubecost_s3_exporter` module.<br />
You'll provide the module-specific inputs in these instances.

#### Create an Instance of the `pipeline` Module and Provide Module-Specific Inputs

The below table lists the required inputs for the `pipeline` module (there are no optional inputs):

| Name                                                               | Description                                                                                                              | Type     | Default | Possible Values                               | Required |
|--------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------|----------|---------|-----------------------------------------------|----------|
| <a name="input_glue_crawler_schedule"></a> glue\_crawler\_schedule | The schedule for the Glue Crawler, in Cron format. Make sure to set it after the last Kubecost S3 Exporter Cron schedule | `string` | n/a     | A Cron expression. For example, `0 1 * * ? *` | yes      |

In the `main.tf` file in the `deploy` directory, you'll find a pre-created `pipeline` module instance:

    module "pipeline" {
      source   = "../modules/pipeline"

      glue_crawler_schedule = ""

Provide the module-specific required inputs, as listed in the above table. Example:

    module "pipeline" {
      source = "../modules/pipeline"

      glue_crawler_schedule = "0 1 * * ? *"
    }

#### Create an Instance of the `kubecost_s3_exporter` Module and Provide Module-Specific Inputs

The below table lists the required and optional inputs for the `kubecost_s3_exporter` module:

| Name                                                                                                                         | Description                                                                                                                   | Type     | Default                                         | Possible Values                                                                                               | Required |
|------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|----------|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------|----------|
| <a name="input_cluster_arn"></a> cluster\_arn                                                                                | The EKS cluster ARN in which the Kubecost S3 Exporter pod will be deployed                                                    | `string` | n/a                                             | An EKS Cluster ARN                                                                                            | yes      |
| <a name="input_cluster_oidc_provider_arn"></a> cluster\_oidc\_provider\_arn                                                  | The IAM OIDC Provider ARN for the EKS cluster                                                                                 | `string` | n/a                                             | An IAM OIDC Provider ARN                                                                                      | yes      |
| <a name="input_kubecost_s3_exporter_container_image"></a> kubecost\_s3\_exporter\_container\_image                           | The Kubecost S3 Exporter container image                                                                                      | `string` | n/a                                             | A Docker container image (`<registry_url>/<repo>:<tag>`)                                                      | yes      |
| <a name="input_kubecost_s3_exporter_container_image_pull_policy"></a> kubecost\_s3\_exporter\_container\_image\_pull\_policy | The image pull policy that'll be used by the Kubecost S3 Exporter pod                                                         | `string` | `"Always"`                                      | One of "Always", "IfNotPresent" or "Never"                                                                    | no       |
| <a name="input_kubecost_s3_exporter_cronjob_schedule"></a> kubecost\_s3\_exporter\_cronjob\_schedule                         | The schedule of the Kubecost S3 Exporter CronJob                                                                              | `string` | `"0 0 * * *"`                                   | A Cron expression. For example, `0 0 * * *`                                                                   | no       |
| <a name="input_kubecost_s3_exporter_ephemeral_volume_size"></a> kubecost\_s3\_exporter\_ephemeral\_volume\_size              | The ephemeral volume size for the Kubecost S3 Exporter pod                                                                    | `string` | `"50Mi"`                                        | A volume size in the format of 'NMi', where N >= 1. For example, 10Mi, 50Mi, 100Mi, 150Mi                     | no       |
| <a name="input_kubecost_api_endpoint"></a> kubecost\_api\_endpoint                                                           | The Kubecost API endpoint in format of 'http://<name\_or\_ip>:<port>'                                                         | `string` | `"http://kubecost-cost-analyzer.kubecost:9090"` | A URI in the format of http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]                            | no       |
| <a name="input_aggregation"></a> aggregation                                                                                 | The aggregation to use for returning the Kubecost Allocation API results                                                      | `string` | `"container"`                                   | One of "container", "pod", "namespace", "controller", "controllerKind", "node", or "cluster" (case-sensitive) | no       |
| <a name="input_kubecost_allocation_api_paginate"></a> kubecost_allocation_api_paginate                                       | Dictates whether to paginate using 1-hour time ranges (relevant for 1h step)                                                  | `string` | `"No"`                                          | One of "Yes", "No", "Y" or "N" (case-insensitive)                                                             | no       |
| <a name="input_kubecost_allocation_api_resolution"></a> kubecost_allocation_api_resolution                                   | The Kubecost Allocation On-demand API resolution, to control accuracy vs performance                                          | `string` | `"1m"`                                          | A resolution in the format of 'Nm', where N >= 1. For example, 1m, 2m, 5m, 10m                                | no       |
| <a name="input_connection_timeout"></a> connection_timeout                                                                   | The time (in seconds) to wait for TCP connection establishment                                                                | `number` | `10`                                            | A float larger than 0 (for example, 0.1, 1, 3.5, 5, 10)                                                       | no       |
| <a name="input_kubecost_allocation_api_read_timeout"></a> kubecost_allocation_api_read_timeout                               | The time (in seconds) to wait for the Kubecost Allocation On-Demand API to send an HTTP response                              | `number` | `60`                                            | A float larger than 0 (for example, 0.1, 1, 3.5, 5, 10)                                                       | no       |
| <a name="input_kubecost_assets_api_read_timeout"></a> kubecost_assets_api_read_timeout                                       | The time (in seconds) to wait for the Kubecost Assets API to send an HTTP response                                            | `number` | `30`                                            | A float larger than 0 (for example, 0.1, 1, 3.5, 5, 10)                                                       | no       |
| <a name="input_tls_verify"></a> tls_verify                                                                                   | Dictates whether TLS certificate verification is done for HTTPS connections                                                   | `string` | `Yes`                                           | One of "Yes", "No", "Y" or "N" (case-insensitive)                                                             | no       |
| <a name="input_kubecost_ca_certificate_secret_name"></a> kubecost\_ca\_certificate\_secret\_name                             | The AWS Secrets Manager secret name, for the CA certificate used for verifying Kubecost's server certificate when using HTTPS | `string` | `""`                                            | A valid AWS Secrets Manager secret name                                                                       | no       |
| <a name="input_k8s_config_path"></a> k8s\_config\_path                                                                       | The K8s config file to be used by Helm                                                                                        | `string` | `"~/.kube/config"`                              | The path to the K8s config file                                                                               | no       |
| <a name="input_namespace"></a> namespace                                                                                     | The namespace in which the Kubecost S3 Exporter pod and service account will be created                                       | `string` | `"kubecost-s3-exporter"`                        | A valid namespace name                                                                                        | no       |
| <a name="input_create_namespace"></a> create\_namespace                                                                      | Dictates whether to create the namespace as part of the Helm Chart deployment                                                 | `bool`   | `true`                                          | `true` or `false`                                                                                             | no       |
| <a name="input_service_account"></a> service\_account                                                                        | The service account for the Kubecost S3 Exporter pod                                                                          | `string` | `"kubecost-s3-exporter"`                        | A valid service account name                                                                                  | no       |
| <a name="input_create_service_account"></a> create\_service\_account                                                         | Dictates whether to create the service account as part of the Helm Chart deployment                                           | `bool`   | `true`                                          | `true` or `false`                                                                                             | no       |
| <a name="input_invoke_helm"></a> invoke\_helm                                                                                | Dictates whether to invoke Helm to deploy the K8s resources (the kubecost-s3-exporter CronJob and the Service Account)        | `bool`   | `true`                                          | `true` or `false`                                                                                             | no       |

In the `main.tf` file in the `deploy` directory, you'll find 2 pre-created `kubecost-s3-exporter` module instances.<br />
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
      cluster_oidc_provider_arn            = ""
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
      cluster_oidc_provider_arn            = ""
      kubecost_s3_exporter_container_image = ""

Change the name of the module instance from "cluster1" to a name that uniquely represents your cluster.<br />
It doesn't have to be the same name as the provider you defined for the cluster, but using consistent naming convention is advised.<br />

Then, provide the module-specific required inputs, as listed in the above table.<br />
Example (more examples can be found in the `examples/deploy/main.tf` file):

    module "cluster1" {
      source = "../modules/kubecost_s3_exporter"

      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster1
        helm         = helm.us-east-1-111111111111-cluster1
      }
    
      cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      cluster_oidc_provider_arn            = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/1"
      kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_cid:0.1.0"
    }

Optionally, change module-specific optional inputs.<br />
Finally, after providing the inputs, change the providers references in the `providers` block:

1. Always leave the `aws.pipeline` field as is.<br />
It references the pipeline provider, and is used by the `kubecost_s3_exporter` module to create the parent IAM role in the pipeline account
2. Change the `aws.eks` field value to the alias of the `aws` provider.<br />
This must be the alias of the `aws` provider you defined for this cluster in the `providers.tf` file
3. If this cluster is deployed using Helm invocation, change the `helm` field value to the alias of the `helm` provider.<br />
This must be the alias of the `helm` provider you defined in the `providers.tf` file for this cluster.<br />
Otherwise, the `helm` field isn't necessary in this module.

Create such a module instance for each cluster on which you wish to deploy the Kubecost S3 Exporter pod.<br />
Make sure that each module instance has a unique name (`module "<unique_name>"`).

**_Important Note:_**<br />
The inline policy created for the IRSA includes some wildcards.<br />
The reason for using these wildcards is to specify:
* All months (part of the S3 bucket prefix)
* All years (part of the S3 bucket prefix)
* All dates in the Parquet file name that is being uploaded to the bucket

Even with these wildcards, the policy restricts access only to a very specific prefix of the bucket.<br />
This is done specifying the account ID, region and EKS cluster name as part of the resource in the inline policy.<br />
This is possible because the prefix we use in the S3 bucket includes the account and region for each cluster, and the Parquet file name includes the EKS cluster name.

### Step 4: Optionally, Add Outputs to the `outputs.tf` File

The `deploy` directory has an `outputs.tf` file, used to show useful outputs after deployment.<br />
Below are explanations on how to use it.

#### The `labels` Output

During the deployment, you may add labels to the dataset for each cluster.<br />
When doing so, Terraform calculates the distinct labels from all clusters labels.<br />
This is done so that Terraform can create a column in the Glue Table, for each distinct label.<br />
This output is included, so that you can make sure the labels were added to the QuickSight dataset.

The `main.tf` file already has a `labels` output, to show the list of distinct labels:

    output "labels" {
      value       = module.pipeline.labels
      description = "A list of the distinct lab of all clusters, that'll be added to the dataset"
    }

No need to make any changes to it.

#### Adding Cluster Outputs for each Cluster

This Terraform module creates an IRSA IAM Role and parent IAM Role for each cluster, as part of the `kubecost-s3-exporter` module.<br />
It creates them with a name that includes the IAM OIDC Provider ID.<br />
This is done to keep the IAM Role name within the length limit, but it causes difficulties in correlating it to a cluster.<br>
You can add an output to the `output.tf` file for each cluster, to show the mapping of the cluster name and the IAM Roles (IRSA and parent) ARNs.

The `outputs.tf` file already has a sample output to get you started:

    output "cluster1" {
      value       = module.cluster1
      description = "The outputs for 'cluster1'"
    }

Change the output name from `cluster1` to a name that uniquely represents your cluster.<br />
Then, change the value to reference to the module instance of your cluster (`module.<module_instance_name>`).
More examples can be found in the `examples/deploy/outputs.tf` file.

It is highly advised that you add an output to the `outputs.tf` file for each cluster, to show the IAM Roles ARNs.<br />
Make sure you use a unique cluster name in the output name.

When deploying, Terraform will output a line showing the output name and the IAM Roles ARNs.

### Step 5: Deploy

From the `deploy` directory, perform the following:

1. Run `terraform init`
2. Run `terraform apply`

## Maintenance

After the solution is initially deployed, you might want to make changes.<br />
Below are instruction for some common changes that you might do after the initial deployment. 

### Deploying on Additional Clusters

When adding additional clusters after the initial deployment, not all the initial deployment steps are required.<br />
To continue adding additional clusters after the initial deployment, the only required steps are as follows, for each cluster:

1. Create an [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html) in the S3 bucket's account.
2. Define additional providers for the clusters
3. Create additional instances of the `kubecost_s3_exporter` module in the `main.tf` file, and provide inputs
4. If you need to add labels for this cluster, follow the "Maintenance -> Adding/Removing Labels to/from the Dataset" section
5. Optionally, add cluster output for the IRSA (IAM Role for Service Account) and parent IAM role, for each cluster

Then, from the `deploy` directory, run `terraform init` and `terraform apply`

### Updating Clusters Inputs

After the initial deployment, you might want to change parameters.<br />
Below are instructions for doing so:

#### Updating Inputs for Existing Clusters

To update inputs for existing clusters (all or some), perform the following:

1. In the `deploy` directory, open the `main.tf` file
2. Change the relevant inputs in the module instances of the clusters you wish to update
3. From the `deploy` directory, run `terraform apply`

### Adding/Removing Labels to/from the Dataset

After the initial deployment, you might want to add or remove labels for some or all clusters, to/from the dataset.<br />
To do this, perform the following:

1. From the `modules/common` directory, open the `variables.tf` file
2. If the cluster for which you'd like to add labels to the dataset, isn't in the `clusters_list` list, add it.<br />
If it's already in the list, and you'd like to update its labels (add/remove), update the `labels` list for this cluster.<br />
If you'd like to remove labels from the dataset for a cluster, remove the cluster's entry from the `clusters_list` list.
3. From the `deploy` directory, run `terraform apply`.<br />
Terraform will output the new list of labels when the deployment is completed.

## Cleanup

### Removing the Kubecost S3 Exporter from Specific Clusters

To remove the Kubecost S3 Exporter from a specific cluster, perform the following:

1. From the `main.tf` file in the `deploy` directory, remove the module instance of the cluster.
2. From the `outputs.tf` file in the `deploy` directory, remove the outputs of the cluster, if any.
3. Run `terraform apply`
4. From the `providers.tf` file in the `deploy` directory, remove the providers of the cluster.<br />
You must remove the providers only after you did step 1-3 above, otherwise the above steps will fail.

### Complete Cleanup

To completely clean up the entire setup, run `terraform destroy` from the `deploy` directory.<br />
Then, follow the "Cleanup" section of the main README.md to clean up other resources that weren't created by Terraform.
