# EKS Insights Dashboard - Architecture

The following is the solution's architecture:

![Screenshot of the solution's architecture](./screenshots/kubecost_cid_architecture.png)

## Solution's Components

The solution is composed of the following resources:

* An S3 bucket that stores the Kubecost data (should be pre-created, see "Requirements" section)
* A CronJob controller (that is used to create a data collection pod) and Service Account.<br />
Both should be deployed on each EKS cluster, using a Terraform module (that invokes Helm) that is provided as part of this solution.<br />
You can also deploy these resources directly using the Helm chart that is provided as part of this solution.<br />
The data collection pod is referred to as Kubecost S3 Exporter throughout some parts of the documentation.
* The following AWS resources (all are deployed using a Terraform module that is provided as part of this solution):
  * IAM Role for Service Account (in the EKS cluster's account) and a parent IAM role (in the S3 bucket's account) for each cluster.<br />
    This is to support cross-account authentication between the data collection pod and the S3 bucket, using IAM role chaining. 
  * AWS Glue Database 
  * AWS Glue Table
  * AWS Glue Crawler (along with its IAM Role and IAM Policy)
  * AWS Secrets Manager Secret (if TLS is enabled)

## High-Level Logic

1. The CronJob K8s controller runs daily and creates a pod that collects cost allocation data from Kubecost. It runs the following API calls:<br />
The [Allocation API](https://docs.kubecost.com/apis/apis-overview/allocation) to retrieve the cost allocation data.<br />
The [Assets API](https://docs.kubecost.com/apis/apis-overview/assets-api) to retrieve the assets' data.<br />
It always collects the data between 72 hours ago 00:00:00 and 48 hours ago 00:00:00.<br />
2. Once data is collected, it's then converted to a Parquet, compressed and uploaded to an S3 bucket of your choice. This is when the CronJob finishes<br />
3. The data is made available in Athena using AWS Glue Database, AWS Glue Table and AWS Glue Crawler.<br />
The AWS Glue Crawler runs daily (using a schedule that you define), to create or update partitions.
4. QuickSight uses the Athena table as a data source to visualize the data

## Cross-Account Authentication Logic

This solution uses IRSA with IAM role chaining, to support cross-account authentication.<br />
For each EKS cluster, the Terraform module that's provided with this solution, will create:

* A child IRSA IAM role in the EKS cluster's account and region
* A parent IAM role in the S3 bucket's account

The child IRSA IAM role will have a Trust Policy that trusts the IAM OIDC Provider ARN.<br />
It's also specifically narrowed down using `Condition` element, to trust it only from the relevant K8s Service Account and Namespace.<br />
The inline policy of the IRSA IAM role allows only the `sts:AssumeRole` action, only for the parent IAM role that was created for this cluster.<br />

The parent IAM role will have a Trust Policy that only trusts the chile IAM role ARN.<br />
The inline policy of the parent IAM role allows only the `s3:PutObject` action, only on the S3 bucket and specific prefix where the Kubecost files for this cluster are expected to be stored.

In addition, an S3 bucket policy sample is provided as part of this documentation (see below "S3 Bucket Specific Notes" section).<br />
The Terraform module that's provided with this solution does not create it, because it doesn't create the S3 bucket.<br />
It's up to you to use it on your S3 bucket. 

## Kubecost APIs Used by this Solution

The Kubecost APIs that are being used are:

* The [Allocation API](https://docs.kubecost.com/apis/apis-overview/allocation) to retrieve the cost allocation data
* The [Assets API](https://docs.kubecost.com/apis/apis-overview/assets-api) to retrieve the assets' data - specifically for the nodes

## Encrypting Data In-Transit

This solution supports encrypting the data between the data collection pod and the Kubecost pod, in-transit.<br />
To enable this, please follow the "Enabling Encryption In-Transit Between the Data Collection Pod and Kubecost Pod" section in the Appendix.

## Back-filling Past Data

This solution supports back-filling past data up to the Kubecost retention limits (15 days for the free tier, 30 days for the business tier).  
The back-filling is done automatically by the data collection pod if it identifies gaps in the S3 data compared to the Kubecost data.  
For more information and use-cases that the back-filling solution solves, see the "Back-filling Past Data" section in the Appendix.

## Logging

Logging is supported in this solution as follows:

1. The data collection container outputs logs to `stdout` or `stderr`. It does NOT support writing logs to an external logging server.  
This is to keep it simple and remove this heavy lifting task from the container.    
It's within your responsibility to run a sidecar container to collect the data collection container logs and write them to an external logging server.  
You're highly encouraged to do so, as the data collection container logs are available for a limited time in the cluster.
2. The AWS Glue Crawler writes logs to Amazon CloudWatch Logs.  
It'll create a Log Group and Log Stream the first time it runs, if those aren't available.
3. All management API made by the data collection container, can be viewed in Amazon CloudTrail if enabled (unless aren't supported by CloudTrail).  
S3 data events can also be logged in CloudTrail, but it requires configuration.  
It's within your responsibility to configure Amazon CloudTrail to log events.
4. Detailed records for the requests that are made to the S3 bucket can be available if S3 server access logs are configured.  
It's recommended to configure S3 server access logs (see [this document](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html))
