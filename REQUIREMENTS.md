# Requirements

Following are the requirements before deploying this solution:

1. An S3 bucket, which will be used to store the [Kubecost](https://www.kubecost.com/products/self-hosted) data
2. QuickSight Enterprise Edition
3. Athena Workgroup, if you choose to not create a custom Athena Workgroup using Terraform
4. An S3 bucket to be used for the Athena Workgroup query results location 
5. Terraform and Helm installed
6. The `cid-cmd` tool ([install with PIP](https://pypi.org/project/cid-cmd/)) installed

For each EKS cluster, have the following:

1. An [IAM OIDC Provider](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).<br />
The IAM OIDC Provider must be created in the EKS cluster's account and region.
2. Kubecost deployed in the EKS cluster.<br />
Currently, only the free tier and the EKS-optimized bundle of Kubecost are supported.<br />
The get the most accurate cost data from Kubecost (such as RIs, SPs and Spot), it's recommended to [integrate it with CUR](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations) and [Spot Data Feed](https://docs.kubecost.com/install-and-configure/install/cloud-integration/aws-cloud-integrations/aws-spot-instances).<br />
To get accurate network costs from Kubecost, please follow the [Kubecost network cost allocation guide](https://docs.kubecost.com/using-kubecost/getting-started/cost-allocation/network-allocation) and deploy [the network costs DaemonSet](https://docs.kubecost.com/install-and-configure/advanced-configuration/network-costs-configuration).

Please continue reading the below more details instructions for some of the above requirements. 

## S3 Bucket Specific Notes - Kubecost Data Bucket

### Using an S3 Bucket Policy

You may create an S3 Bucket Policy on the bucket that you create to store the Kubecost data.<br />
In this case, below is a recommended bucket policy to use.<br />
This bucket policy, along with the identity-based policies of all the identities in this solution, provide minimum access:

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:*",
                "Resource": [
                    "<your_kubecost_bucket_arn>",
                    "<your_kubecost_bucket_arn>/*"
                ],
                "Condition": {
                    "Bool": {
                        "aws:SecureTransport": "false"
                    },
                    "StringNotEquals": {
                        "aws:PrincipalArn": [
                            "arn:aws:iam::<account_id>:role/<your_bucket_management_role>",
                            "arn:aws:iam::<account_id>:role/kubecost_glue_crawler_role",
                            "arn:aws:iam::<account_id>:role/service-role/aws-quicksight-service-role-v0"
                        ],
                        "aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"
                    },
                    "NumericLessThan": {
                        "s3:TlsVersion": "1.2"
                    }
                }
            }
        ]
    }

This S3 bucket denies all principals from performing all S3 actions, except the principals in the `Condition` section.<br />
The list of principals shown in the above bucket policy are as follows:

* The `arn:aws:iam::<account_id>:role/<your_bucket_management_role>` principal:<br />
This principal is an example of an IAM Role you may use to manage the bucket.
Add the IAM Roles that will allow you to perform administrative tasks on the bucket.
* The `arn:aws:iam::<account_id>:role/kubecost_glue_crawler_role` principal:<br />
This principal is the IAM Role that will be attached to the Glue Crawler when it's created by Terraform.<br />
You must add it to the bucket policy, so that the Glue Crawler will be able to crawl the bucket.
* The `arn:aws:iam::<account_id>:role/service-role/aws-quicksight-service-role-v0` principal:<br />
This principal is the IAM Role that will be automatically created for QuickSight.<br />
If you use a different role, please change it in the bucket policy.<br />
You must add this role to the bucket policy, for proper functionality of the QuickSight dataset that is created as part of this solution.
* The `aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"` condition:<br />
This condition identifies all the EKS clusters from which the Kubecost S3 Exporter pod will communicate with the bucket.<br />
When Terraform creates the IAM roles for the pod to access the S3 bucket, it tags the parent IAM roles with the above tag.<br />
This tag is automatically being used in the IAM session when the Kubecost S3 Exporter pod authenticates.<br />
The reason for using this tag is to easily allow all EKS clusters running the Kubecost S3 Exporter pod, in the bucket policy, without reaching the bucket policy size limit.<br />
The other alternative is to specify all the parent IAM roles that represent each cluster one-by-one.<br />
With this approach, the maximum bucket policy size will be quickly reached, and that's why the tag is used.

The resources used in this S3 bucket policy include:

* The bucket name, to allow access to it
* All objects in the bucket, using the `arn:aws:s3:::kubecost-data-collection-bucket/*` string.<br />
The reason for using a wildcard here is that multiple principals (multiple EKS clusters) require access to different objects in the bucket.<br />
Using specific objects for each principal will result in a longer bucket policy that will eventually exceed the bucket policy size limit.<br />
The identity policy (the parent IAM role) that is created as part of this solution for each cluster, specifies only the specific prefix and objects.<br >
Considering this, the access to the S3 bucket is more specific than what's specified in the "Resources" part of this bucket policy.

### Setting Server-Side Encryption

It's highly recommended that server-side encryption is set on your S3 Bucket.  
See [this documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-encryption.html) for more information.  
Please note that starting January 5th, 2023, Amazon S3 encrypts new objets by default.  
See [this announcement](https://aws.amazon.com/blogs/aws/amazon-s3-encrypts-new-objects-by-default/) for more information.

### Access to the Bucket

It's advised to block public access to the S3 bucket (see [this document](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)).  
The S3 bucket that stores the Kubecost data is meant to be accessed only from the EKS clusters.  
Also, it's advised to use VPC Endpoints to make sure traffic towards the S3 bucket does not traverse the internet 

## Configure Athena Query Results Location

An Athena Workgroup can be used by this solution, which also requires setting Athena Query Results Location in the Workgroup.  
By default, Terraform will create an Athena Workgroup, but you can also choose that it won't.  
Depending on your choice, there are different requirements that you need to go though, before deployment.  
Please either proceed to the "Athena Requirements for Terraform-Created Workgroup" or to the "Athena Requirements for Self-Created Workgroup"

### Athena Requirements for Terraform-Created Workgroup

Following are the requirements when choosing the use the Terraform-Created Workgroup:

#### Step 1: Create an S3 bucket that will be used for the Athena Workgroup Query Results Location  

This S3 bucket will be used to write the Athena query results.  
You'll have to give this bucket name as an input in a Terraform variable (documented separately in the Terraform README.md). 

#### Step 2: Configure permissions in QuickSight to access the above S3 bucket  

In QuickSight, go to "Manage QuickSight" (top right), then "Security & permissions" on the left.  
Click "Manage" under "Access granted to X services", then select Athena and click "Next".  
Select the S3 bucket that you created above.  
Also, make sure you select S3 buckets required by other QuickSight data sources, otherwise you these data sources may lose access.  
Then, click "Finish" and "Save".

If you get an error as the below:

    We cannot update the IAM Role. The reason could be one or more from the following:
      The role does not explicitly trust QuickSight service principal.
      Following policies are either not attached to the QuickSight role or attached to more than one:
          arn:aws:iam::<account_id>:policy/service-role/AWSQuickSightS3Policy
      Make sure the credentials you're using have following permissions:
          iam:CreateRole, iam:CreatePolicy, iam:AttachRolePolicy, iam:CreatePolicyVersion, iam:DeletePolicyVersion, iam:ListAttachedRolePolicies, iam:GetRole, iam:GetPolicy, iam:DetachRolePolicy, iam:GetPolicyVersion and iam:ListPolicyVersions

Then you need to add the permissions directly in the IAM console.  
This easiest way to do it is to find the predefined IAM Role named `aws-quicksight-service-role-v0`.  
In it, there's an attached predefined IAM Policy named `AWSQuicksightAthenaAccess`.  
You can't edit it, so copy its contents (JSON), and create a new IAM Policy/inline policy.  
Paste the JSON you copied into the new policy, and change the bucket name to the one you created (make sure you end with a wildcard).  
Then, attach the policy to the IAM Role (unless you created an inline policy).

Not following the above procedure will result in the following error later when creating the QuickSight Data Source that uses the Athena Workgroup:  

    GENERIC_SQL_FAILURE: [Simba][AthenaJDBC](100071) An error has been thrown from the AWS Athena client. Unable to verify/create output bucket <bucket_name>


If you followed this process but didn't add wildcard in the end of the bucket resource in the IAM policy, it'll result in the following error later when creating the QuickSight Data Source:

    ACCESS_DENIED_TO_RESULT_STAGING_AREA [Simba][AthenaJDBC](100071) An error has been thrown from the AWS Athena client. Access denied when writing to location: s3://<bucket_name>/<file_name>

### Athena Requirements for Self-Created Workgroup

If you choose that Terraform won't create an Athena Workgroup for you, please follow the below requirements for the workgroup you plan to use:

#### Step 1: Create an S3 bucket that will be used for the Athena Workgroup Query Results Location  

This S3 bucket will be used to write the Athena query results.  

#### Step 2: Set Query Results Location in the Athena Workgroup Settings

Navigate to Athena Console -> Administration -> Workgroups:
![Screenshot of Athena Workgroups Page](./screenshots/athena_workgroups_page.png)

Click on the relevant Workgroup, and you'll see the Workgroup settings:
![Screenshot of Athena Workgroups Settings View](./screenshots/athena_workgroup_settings_view.png)

If the "Query result location" field is empty, go back to the Workgroups page, and edit the Workgroup settings:
![Screenshot of Athena Workgroups Page Edit Workgroup](./screenshots/athena_workgroups_page_edit_workgroup.png)

In the settings page, set the Query results location.  
Optionally (recommended), encrypt the query results, and save:
![Screenshot of Athena Workgroup Settings Edit](./screenshots/athena_workgroup_settings_edit.png)

#### Step 3: Configure permissions in QuickSight to access the above S3 bucket

Follow the same steps as in step 2 of the "Athena Requirements for Terraform-Created Workgroup".  

## Configure QuickSight Permissions for the Kubecost Data S3 Bucket

1. Navigate to “Manage QuickSight → Security & permissions”
2. Under “Access granted to X services”, click “Manage”
3. Under “S3 Bucket”, check the S3 bucket you created for the Kubecost data

Note - if at step 2 above, you get the following error:

*Something went wrong*
*For more information see Set IAM policy (https://docs.aws.amazon.com/console/quicksight/iam-qs-create-users)*

1. Navigate to the IAM console
2. Edit the QuickSight-managed S3 IAM Policy (usually named `AWSQuickSightS3Policy`)
3. Add the S3 bucket in the same sections of the policy where you have your CUR bucket
