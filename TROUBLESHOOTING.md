# Troubleshooting

This document includes some common issues and possible solutions.

## Kubecost S3 Exporter Data Collection Issues

This section includes common issues related to the Kubecost S3 Exporter.

### The Data Collection Pod is in Status of `Completed`, But There's No Data in the S3 Bucket

The data collection container collects data between 72 hours ago 00:00:00.000 and 48 hours ago 00:00:00.000.  
Your Kubecost server still have missing data in this timeframe.  
Please check the data collection container logs, and if you see the below message, it means you still don't have enough data:

    <timestamp> ERROR kubecost-s3-exporter: API response appears to be empty.
    This script collects data between 72 hours ago and 48 hours ago.
    Make sure that you have data at least within this timeframe.

In this case, please wait for Kubecost to collect data for 72 hours ago, and then check again.

### The Data Pod Container is in Status of `Error`

This could be for various reasons.  
Below are a couple of scenarios caught by the data collection container, and their logs you should expect to see.

#### A Connection Establishment Timeout

In case of a connection establishment timeout, the container logs will show the following log:

    <timestamp> ERROR kubecost-s3-exporter: Timed out waiting for TCP connection establishment in the given time ({connection_timeout}s). Consider increasing the connection timeout value.

In this case, please check the following:

1. That you specified the correct Kubecost API endpoint in the `kubecost_api_endpoint` input.
This should be the Kubecost cost-analyzer service.  
Usually, you should be able to specify `http://<service_name>.<namespace_name>:[port]`, and this DNS name will be resolved.
The default service name for Kubecost cost-analyzer service is `kubecost-cost-analyzer`, and the default namespace it's created in is `kubecost`.  
The default port the Kubecost cost-analyzer service listens on is TCP 9090.  
Unless you changed the namespace, service name or port, you should be good with the default value of the `kubecost_api_endpoint` input.  
If you changed any of the above, make sure you change the `kubecost_api_endpoint` input value accordingly.
2. If the `kubecost_api_endpoint` input has the correct value, try increasing the `connection_timeout` input value
3. If you still get the same error, check network connectivity between the data collection pod and the Kubecost cost-analyzer service

#### An HTTP Server Response Timeout

In case of HTTP server response timeout, the container logs will show one of the following logs (depends on the API being queried):

    <timestamp> ERROR kubecost-s3-exporter: Timed out waiting for Kubecost Allocation On-Demand API to send an HTTP response in the given time ({read_timeout}s). Consider increasing the read timeout value.

    <timestamp> ERROR kubecost-s3-exporter: Timed out waiting for Kubecost Assets API to send an HTTP response in the given time ({read_timeout}s). Consider increasing the read timeout value.

If this is for the Allocation On-Demand API call, please follow the recommendations in the "Clarifications on the Allocation On-Demand API" part on the Appendix.  
If this is for the Assets API call, please try increasing the `kubecost_assets_api_read_timeout` input value.

## Terraform Issues

This section includes common issues related to Terraform.

### An `AccessDeniedException` Error Related to QuickSight Identity Region

If you get the following error when executing `terraform apply`:

    │ Error: reading QuickSight User (): AccessDeniedException: Operation is being called from endpoint eu-west-2, but your identity region is eu-west-1. Please use the eu-west-1 endpoint.
    │ {
    │   RespMetadata: {
    │     StatusCode: 401,
    │     RequestID: "<request_id>"
    │   },
    │   Message_: "Operation is being called from endpoint eu-west-2, but your identity region is eu-west-1. Please use the eu-west-1 endpoint."
    │ }
    │
    │   with module.quicksight.data.aws_quicksight_user.qs_current_user,
    │   on modules/quicksight/main.tf line 25, in data "aws_quicksight_user" "qs_current_user":
    │   25: data "aws_quicksight_user" "qs_current_user" {
    │

It means the region you defined in the `quicksight-identity` provider is incorrect.  
Switch it to the region mentioned in the error (`eu-west-1` in this example).  
This is done in the [`providers.tf`](terraform/terraform-aws-cca/providers.tf) file in the root directory of the Terraform module

### Waiting from QuickSight Data Source

If you get the following error when executing `terraform apply`:

    ╷
    │ Error: waiting from QuickSight Data Source (<account_id>/<request_id>) creation: unexpected state 'CREATION_FAILED', wanted target 'CREATION_SUCCESSFUL'. last error: GENERIC_SQL_FAILURE: [Simba][AthenaJDBC](100071) An error has been thrown from the AWS Athena client. Unable to verify/create output bucket <bucket_name> [Execution ID not available]
    │
    │   with module.quicksight.aws_quicksight_data_source.cca,
    │   on modules/quicksight/main.tf line 73, in resource "aws_quicksight_data_source" "cca":
    │   73: resource "aws_quicksight_data_source" "cca" {
    │

It means QuickSight doesn't have write permissions to your Athena query results location bucket.  
Please follow [the instructions to configure these permissions](REQUIREMENTS.md/.#configure-quicksight-permissions-for-the-s3-buckets).

### A `LimitExceededException` Error Related to QuickSight SPICE Capacity

If you get the following error when executing `terraform apply`:

    ╷
    │ Error: creating QuickSight Data Set: LimitExceededException: Insufficient SPICE capacity
    │ {
    │   RespMetadata: {
    │     StatusCode: 409,
    │     RequestID: "36800807-aacc-49df-b554-7ee9b1032bdb"
    │   },
    │   Message_: "Insufficient SPICE capacity"
    │ }
    │
    │   with module.quicksight.aws_quicksight_data_set.cca,
    │   on modules/quicksight/main.tf line 126, in resource "aws_quicksight_data_set" "cca":
    │  126: resource "aws_quicksight_data_set" "cca" {
    │
    ╵

It means you don't have enough capacity to create the QuickSight dataset.  
Make sure you add [enough SPICE capacity](REQUIREMENTS.md/.#verifying-enough-quicksight-spice-capacity).
