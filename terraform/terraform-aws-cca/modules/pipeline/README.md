# Pipline Module

The Pipeline reusable module is used deploy the pipeline AWS resources for this solution.

## Define Provider

In the [`providers.tf`](../../providers.tf) file in the root directory, you'll find a pre-created `aws` provider for the `pipeline` module:

    #####################################
    # Section 1 - Pipeline AWS Provider #
    #####################################
    
    # Provider for the pipeline module
    provider "aws" {
    
      # This is an example, to help you get started
    
      region                   = "us-east-1"            # Change the region if necessary
      shared_config_files      = ["~/.aws/config"]      # Change the path to the shared config file, if necessary
      shared_credentials_files = ["~/.aws/credentials"] # Change the path to the shared credential file, if necessary
      profile                  = "pipeline_profile"     # Change to the profile that will be used for the account and region where the pipeline resources will be deployed
      default_tags {
        tags = module.common_variables.aws_common_tags
      }
    }

* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the pipeline resources 

Examples can be found in the [`examples/root_module/providers.tf`](../../examples/root_module/providers.tf) file.

## Create a Calling Module and Provide Variables Values

In the [`main.tf`](../../main.tf) file in the root directory, you'll find a pre-created `pipeline` calling module:

    ######################################
    # Section 2 - AWS Pipeline Resources #
    ######################################
    
    # Calling module for the pipeline module, to create the AWS pipeline resources
    module "pipeline" {
      source = "./modules/pipeline"
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module, do not remove or change
    
      bucket_arn      = module.common_variables.bucket_arn
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                           #
      # Pipeline Module Variables #
      #                           #
    
      # Provide optional pipeline module variables values here, if needed
    
    }

Variables referenced from the `common_variables` module are already present, please do not change or remove them.  
The `pipeline` module's own variables are all optional.  
If you don't need to change one of the optional variables, you can leave the pre-created calling module as is.

For more information on the variables, see this module's [`variables.tf` file](variables.tf).  
For examples, see the [`examples/root_module/main.tf` file](../../examples/root_module/main.tf).
