# Kubecost S3 Exporter Module

The Kubecost S3 Exporter reusable module is used deploy the Kubecost S3 Exporter, including:

* The K8s resources (CronJob and Service Account)
* IAM roles

## Define Provider for each EKS Cluster

In the [`providers.tf`](../../providers.tf) file in the root directory, you'll find 3 pre-created providers for a sample cluster.  
The first 2 are for a cluster with Helm invocation, and the last one is for cluster without Helm invocation:

    ###########################################################
    # Section 2 - Kubecost S3 Exporter AWS and Helm Providers #
    ###########################################################
    
    # Providers for the kubecost_s3_exporter module.
    # Used to deploy the K8s resources on clusters, and creates IRSA in cluster's accounts
    # There are 2 deployment options:
    #
    # 1. Deploy the K8s resources by having Terraform invoke Helm
    #    In this case, you have to define 2 providers per cluster - an AWS provider and a Helm provider
    # 2. Deploy the K8s resources by having Terraform generate a Helm values.yaml, then you deploy it using Helm
    #    In this case, you have to define 1 provider per cluster - an AWS provider
    
    #                                                    #
    # Example providers for cluster with Helm invocation #
    #                                                    #
    
    # Use these providers if you'd like Terraform to invoke Helm to deploy the K8s resources
    # Duplicate the providers for each cluster on which you wish to deploy the Kubecost S3 Exporter
    
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster1"          # Change to an alias that uniquely identifies the cluster within all the AWS provider blocks
    
      region                   = "us-east-1"             # Change the region if necessary
      shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
      shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
      profile                  = "profile1"              # Change to the profile that identifies the account and region where the cluster is
      default_tags {
        tags = module.common_variables.aws_common_tags
      }
    }
    
    provider "helm" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster1"                                 # Change to an alias that uniquely identifies the cluster within all the Helm provider blocks
    
      kubernetes {
        config_context = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"  # Change to the context that identifies the cluster in the K8s config file (in many cases it's the cluster ARN)
        config_path    = "~/.kube/config"                                       # Change to the full path of the K8s config file
      }
    }
    
    #                                                       #
    # Example provider for cluster without Helm invocation  #
    #                                                       #
    
    # Use this provider if you'd like Terraform to generate a Helm values.yaml, then you deploy it using Helm
    # Duplicate the provider for each cluster on which you wish to deploy the Kubecost S3 Exporter
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "us-east-1-111111111111-cluster2"          # Change to an alias that uniquely identifies the cluster within all AWS Helm provider blocks
    
      region                   = "us-east-1"             # Change the region if necessary
      shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
      shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
      profile                  = "profile1"              # Change to the profile that identifies the account and region where the cluster is
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

Examples can be found in the [`examples/root_module/providers.tf`](../../examples/root_module/providers.tf) file.

## Create a Calling Module and Provide Variables Values

In the [`main.tf`](../../main.tf) file in the root directory, you'll find 2 pre-created `kubecost_s3_exporter` calling modules.  
The first one is for a cluster with Helm invocation, and the last one is for a cluster without Helm invocation:

    #########################################################
    # Section 3 - Data Collection Pod Deployment using Helm #
    #########################################################
    
    # Calling modules for the kubecost_s3_exporter module.
    # Deploys the K8s resources on clusters, and creates IRSA in cluster's accounts
    # There are 2 deployment options:
    #
    # 1. Deploy the K8s resources by having Terraform invoke Helm
    #    This option is shown in the "cluster1" calling module example
    # 2. Deploy the K8s resources by having Terraform generate a Helm values.yaml, then you deploy it using Helm
    #    This option is shown in the "cluster2" calling module example
    
    # Example calling module for cluster with Helm invocation
    # Use it if you'd like Terraform to invoke Helm to deploy the K8s resources
    # Replace "cluster1" with a unique name to identify the cluster
    # Duplicate the calling module for each cluster on which you wish to deploy the Kubecost S3 Exporter
    module "cluster1" {
    
      # This is an example, to help you get started
    
      source = "./modules/kubecost_s3_exporter"
    
      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster1  # Replace with the AWS provider alias for the cluster
        helm         = helm.us-east-1-111111111111-cluster1 # Replace with the Helm provider alias for the cluster
      }
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module
      # Always include when creating new calling module, and do not remove or change
    
      bucket_arn      = module.common_variables.bucket_arn
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = "" # Add the EKS cluster ARN here
      kubecost_s3_exporter_container_image = "" # Add the Kubecost S3 Exporter container image here (example: 111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0)
    }
    
    # Example calling module for cluster without Helm invocation
    # Use it if you'd like Terraform to generate a Helm values.yaml, then you deploy it using Helm
    # Replace "cluster2" with a unique name to identify the cluster
    # Duplicate the calling module for each cluster on which you wish to deploy the Kubecost S3 Exporter
    module "cluster2" {
    
      # This is an example, to help you get started
    
      source = "./modules/kubecost_s3_exporter"
    
      providers = {
        aws.pipeline = aws
        aws.eks      = aws.us-east-1-111111111111-cluster2 # Replace with the AWS provider alias for the cluster
      }
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module
      # Always include when creating new calling module, and do not remove or change
    
      bucket_arn      = module.common_variables.bucket_arn
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = "" # Add the EKS cluster ARN here
      kubecost_s3_exporter_container_image = "" # Add the Kubecost S3 Exporter container image here (example: 111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0)
      invoke_helm                          = false
    }

### Rename the Calling Module 

Rename of the calling module from "cluster1" to a name that uniquely represents your cluster.  
It doesn't have to be the same name as the provider alias you defined for the cluster, but using consistent naming convention is advised.

### Change Providers References

Change the providers references in the `providers` block:

1. Always leave the `aws.pipeline` field as is.  
It references the pipeline provider, and is used by the `kubecost_s3_exporter` reusable module to create the parent IAM role in the pipeline account
2. Change the `aws.eks` field value to the alias of the `aws` provider.  
This must be the alias of the `aws` provider you defined for this cluster in the `providers.tf` file
3. If this cluster is deployed using Helm invocation, change the `helm` field value to the alias of the `helm` provider.  
This must be the alias of the `helm` provider you defined in the `providers.tf` file for this cluster.  
Otherwise, the `helm` field isn't necessary in this calling module.

### Provide Variables Values

Variables referenced from the `common_variables` module are already present, please do not change or remove them.  
The `kubecost_s3_exporter` module has 2 required variables:
* The `cluster_arn` variable, where you must input the EKS cluster ARN
* The `kubecost_s3_exporter_container_image`, where you must input the Kubecost S3 Exporter Docker image.
That's the image you built and pushed in ["Step 2: Build and Push the Container Image" in the DEPLOYMENT.md file](../../../../DEPLOYMENT.md/.#step-1-build-and-push-the-container-image).

Example:

    module "cluster1" {
      source = "./modules/kubecost_s3_exporter"

      ... omitted output ...

      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster1"
      kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0"
    }

If you're deploying this module without Helm invocation ["Deployment Option 2" in the DEPLOYMENT.md file](../../../../DEPLOYMENT.md/.#deployment-option-2):  
Make sure the `invoke_helm` has value of `false`, as below:

    module "cluster2" {
      source = "./modules/kubecost_s3_exporter"

      ... omitted output ...

      #                                       #
      # Kubecost S3 Exporter Module Variables #
      #                                       #
    
      # Provide kubecost_s3_exporter module variables values here
    
      cluster_arn                          = "arn:aws:eks:us-east-1:111111111111:cluster/cluster2"
      kubecost_s3_exporter_container_image = "111111111111.dkr.ecr.us-east-1.amazonaws.com/kubecost_s3_exporter:0.1.0"
      invoke_helm                          = false
    }

Provide optional variables values if needed.

For more information on the variables, see this module's [`variables.tf` file](variables.tf).  
For examples, see the [`examples/root_module/main.tf` file](../../examples/root_module/main.tf).

#### Notes

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

### Deploy on Additional Clusters

Repeat the above steps for this calling module, for each cluster on which you wish to deploy the Kubecost S3 Exporter.  
Make sure that each calling module has a unique name (`module "<unique_name>"`).

## Adding Outputs for each Cluster

This Terraform module creates an IRSA IAM Role and parent IAM Role for each cluster, as part of the `kubecost_s3_exporter` module.  
It creates them with a name that includes the IAM OIDC Provider ID.  
This is done to keep the IAM Role name within the length limit, but it also causes difficulties in correlating it to a cluster.  
You can add an output to the [`output.tf`](../../outputs.tf) file in the root directory for each cluster.  
This is to show the mapping of the cluster name and the IAM Roles (IRSA and parent) ARNs.

The [`outputs.tf`](../../outputs.tf) file in the root directory already has a sample output to get you started:

    #output "cluster1" {
    #  value       = module.cluster1
    #  description = "The outputs for 'cluster1'"
    #}

* Uncomment the output block.  
* Change the output name from `cluster1` to a name that uniquely represents your cluster.  
* Change the value to reference to the calling module of your cluster (`module.<calling_module_name>`).

More examples can be found in the [`examples/root_module/outputs.tf` file](../../examples/root_module/outputs.tf).
