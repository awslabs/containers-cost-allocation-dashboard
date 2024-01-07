# QuickSight Module

The QuickSight reusable module is used deploy the QuickSight resources for this solution.

## Define Providers

In the [`providers.tf`](../../providers.tf) file in the root directory, you'll find 2 pre-created `aws` providers for the `quicksight` module:

    #######################################
    # Section 3 - Quicksight AWS Provider #
    #######################################
    
    #                          #
    # Providers for QuickSight #
    #                          #
    
    # Providers for the QuickSight module.
    # Used to deploy the QuickSight resources and to identify the QuickSight users
    # It has 2 providers:
    #
    # 1. The first provider block is to identify the account and QuickSight region where the dashboard will be deployed
    # 2. The second provider block is to identify the QuickSight identity region (where the QuickSight users are)
    #    To identify the identity region:
    #    a. Log in to QuickSight
    #    b. On the top right, click the person button, and switch to the region where you intend to deploy the dashboard.
    #       This is the same region as in the first provider
    #    c. On the top right, click the person button again, and click "Manage QuickSight"
    #    d. On the left pane, click "Security & permissions".
    #       If you see the "Security & permissions" page, then the identity region is the same as the dashboard region.
    #       If you see a message "Switch to `<region name>` to edit permissions or unsubscribe", then the region in the message is the identity region.
    #       Use it in the `region` field on the second provider block
    
    # Provider for QuickSight account and region where the dashboard will be deployed
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "quicksight"
    
      region                   = "us-east-1"             # Change the region if necessary. This is the region you select on the top right part of the QuickSight UI
      shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
      shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
      profile                  = "quicksight_profile"    # Change to the profile that will be used for the account and region where the QuickSight dashboard will be deployed
      default_tags {
        tags = module.common_variables.aws_common_tags
      }
    }
    
    # Provider for QuickSight identity region
    provider "aws" {
    
      # This is an example, to help you get started
    
      alias = "quicksight-identity"
    
      region                   = "us-east-1"             # Change the region if necessary. This is the region you identified in the steps above
      shared_config_files      = ["~/.aws/config"]       # Change the path to the shared config file, if necessary
      shared_credentials_files = ["~/.aws/credentials"]  # Change the path to the shared credential file, if necessary
      profile                  = "quicksight_profile"    # Change to the profile that will be used to identify the QuickSight identity region
      default_tags {
        tags = module.common_variables.aws_common_tags
      }
    }

The first provider (aliased `quicksight`) is for the QuickSight region where the dashboard is deployed.  
The second provider (aliased `quicksight-identity`) is for the QuickSight identity region where QuickSight users are.

In the first provider:
* Change the `region` field if needed
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the QuickSight resources 

In the second provider:
* Change the `region` field if needed.  
To identify the identity region:
  * Log in to QuickSight
  * On the top right, click the person button, and switch to the region where you intend to deploy the dashboard.  
  This is the same region you gave as input in the first provider.
  * On the top right, click the person button again, and click "Manage QuickSight"
  * On the left pane, click "Security & permissions".
  If you see the "Security & permissions" page, then the identity region is the same as the dashboard region.  
  If you see a message "Switch to `<region name>` to edit permissions or unsubscribe", then the region in the message is the identity region.
* Change the `shared_config_files` and `shared_credentials_files` if needed
* Change the `profile` field to the AWS Profile that Terraform should use to create the QuickSight resources 

Examples can be found in the [`examples/root_module/providers.tf`](../../examples/root_module/providers.tf) file.

## Create a Calling Module and Provide Variables Values

In the [`main.tf`](../../main.tf) file in the root directory, you'll find a pre-created `quicksight` calling module:

    ####################################
    # Section 4 - Quicksight Resources #
    ####################################
    
    # Calling module for the quicksight module, to create the QuickSight resources
    module "quicksight" {
      source = "./modules/quicksight"
    
      providers = {
        aws          = aws.quicksight
        aws.identity = aws.quicksight-identity
      }
    
      #                         #
      # Common Module Variables #
      #                         #
    
      # References to variables outputs from the common module, do not remove or change
    
      k8s_labels      = module.common_variables.k8s_labels
      k8s_annotations = module.common_variables.k8s_annotations
      aws_common_tags = module.common_variables.aws_common_tags
    
      #                           #
      # Pipeline Module Variables #
      #                           #
    
      # References to variables outputs from the pipeline module, do not remove or change
    
      glue_database_name = module.pipeline.glue_database_name
      glue_view_name     = module.pipeline.glue_view_name
    
      #                             #
      # QuickSight Module Variables #
      #                             #
    
      # Provide quicksight module variables values here
    
      # This configuration block is used to define Athena workgroup
      # There are 2 options to use it:
      #
      # 1. Have Terraform create the Athena workgroup for you (the first uncommented block)
      # 2. Use an existing Athena workgroup (the second commented block)
    
      # Add an S3 bucket name for Athena Workgroup Query Results Location, if var.athena_workgroup_configuration.create is "true"
      # It must be different from the S3 bucket used to store the Kubecost data
      # If you decided to use var.athena_workgroup_configuration.create as "false", remove the below field
      # Then, add the "name" field and specify and existing Athena workgroup
    
      # Block for having Terraform create Athena workgroup
      # You can optionally add the "name" field to change the default name that will used ("kubecost")
      athena_workgroup_configuration = {
        query_results_location_bucket_name = "" # Add an S3 bucket name for Athena Workgroup Query Results Location. It must be different from the S3 bucket used to store the Kubecost data
      }
    
      # Block for using an existing Athena workgroup
      # If you want to use it, comment the first block above, and uncomment the block below, then give the inputs
      # You can optionally add the "name" field to change the default name that will used ("kubecost")
    #  athena_workgroup_configuration = {
    #    create                             = false
    #    name                               = "" # Add a name of an existing Athena Workgroup. Make sure it has Query Results Location set to an existing S3 bucket w hich is different from the S3 bucket used to store the Kubecost data
    #    query_results_location_bucket_name = "" # Add an S3 bucket name for Athena Workgroup Query Results Location. It must be different from the S3 bucket used to store the Kubecost data
    #  }
    
    }

Variables referenced from the `common_variables` module are already present, please do not change or remove them.  
The `quicksight` module has one required variable - `athena_workgroup_configuration`.  
It's used by to create an Athena workgroup or to reference an existing one:  
* When using it to create an Athena workgroup, the `query_results_location_bucket_name` field in it is required.  
In this case, you must provide an S3 bucket name, and it must be different from the S2 bucket used to store the Kubecost data.  
You can also optionally provide the `name` field inside the `athena_workgroup_configuration` block, if you want to change the default name.
* When using it to reference an existing Athena workgroup, you must use the `create` field as `false` in the `athena_workgroup_configuration` block.  
In this case, the `name` field becomes required, and you must provide an existing Athena workgroup name.  
The `query_results_location_bucket_name` in this case, is ignored.

For more information on the variables, see this module's [`variables.tf` file](variables.tf).  
For examples, see the [`examples/root_module/main.tf` file](../../examples/root_module/main.tf).
