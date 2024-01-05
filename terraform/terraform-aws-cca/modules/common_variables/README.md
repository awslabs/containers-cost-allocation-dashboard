# The `common_variables` Module

The `common_variables` reusable module is used to provide common variables that are used by other modules.

## Create a Calling Module for the `common_variables` Module and Provide Variables Values

The deployment of this solution involves both AWS resources deployment and a data collection pod (Kubecost S3 Exporter) deployment.  
Both have common variables, and to make things easy, the `common_variables` module is provided for this purpose.

In the [`main.tf`](../../main.tf) file in the root directory, you'll find a pre-created `common_variables` calling module:

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

For more information on the variables, see this module's [`variables.tf` file](variables.tf).  
For examples, see the [`examples/root_module/main.tf` file](../../examples/root_module/main.tf).

## The `labels` and `annotations` Outputs

During the deployment, you may add labels or annotations to the dataset for each cluster, as explained above.
The `labels` and `annotations` outputs are for you to use easily find them in cases such as:

* Using Helm to deploy the K8s resources (the labels and annotations must be given in Helm values as inputs)
* Creating visuals with these labels or annotations

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
