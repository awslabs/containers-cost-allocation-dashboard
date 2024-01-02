# Security

## Enabling Encryption In-Transit Between the Data Collection Pod and Kubecost Pod

By default, the Kubecost `cost-analyzer-frontend` service uses HTTP service to serve the UI/API endpoints, over TCP port 9090.  
For secure communication between the data collection pod and the Kubecost service, it's recommended to encrypt the data in-transit.  
To do that, you first need to enable TLS in Kubecost, and then enable communication over HTTPS in the data collection pod.  
Below you'll find the necessary steps to take.

### Enabling TLS in Kubecost `cost-analyzer-frontend` Container

At the time of writing this document, Kubecost doesn't have any public documentation on enabling TLS.  
This section will help you go through enabling TLS in Kubecost.  
This section does not intend to replace the Kubecost user guide, and if you have any doubts, please contact Kubecost support.

To enable TLS in Kubecost, please take the following steps:

1. Create a TLS Secret in the Kubecost namespace, for the server certificate and private key you intend to use in Kubecost.  
You can use the below `kubectl` command [1] to create the Secret object:  
Note that the private key must have no passphrase, otherwise, you'll get `error: tls: failed to parse private key` error when executing this command.  
It's advised that you'll use a server certificate that's signed by a root CA certificate, and not a self-signed certificate.

2. Enable TLS in Kubecost by changing the below values [2] in the Kubecost Helm chart.  
See full `helm` command example below [3].  
Once the Helm upgrade finishes successfully, you should see the Kubecost service listens on port 443.  
See example of the `kubectl get services` command output below [4].

### Enabling TLS Communication in the Data Collection Pod

Enabling TLS in the data collection pod is done on per pod basis on each cluster.  
This is because the same is done on per pod basis in Kubecost, and Kubecost is installed separately on each cluster.  
Please take the following steps to enable TLS communication in the data collection pod:

1. In the [`main.tf`](terraform/cca_terraform_module/main.tf) file in the root directory of the Terraform module:  
Add the `kubecost_api_endpoint` variable to the cluster's calling module, for the clusters where you enabled TLS in Kubecost.  
By default, if you don't add this variable to the calling module, the data collection pod uses `http://kubecost-cost-analyzer.kubecost:9090` to communicate with Kubecost.  
To make sure the data collection pod uses TLS when communicating with the Kubecost pod, the URL in this variable must start with `https`.  
For example, use `https://kubecost-cost-analyzer.kubecost` (note no port is defined, meaning TCP port 443 is used).  
Note that by default, when enabling TLS in Kubecost frontend container, it uses TCP port 443.  
In future versions, Kubecost will change the default port when using TLS, to TCP port 9090 (in this case, use `https://kubecost-cost-analyzer.kubecost:9090` in `kubecost_api_endpoint`)
2. If you're using a self-signed server certificate in Kubecost, disable TLS verification in the data collection pod.  
Do so by adding `tls_verify` variable with value of `false`, in the cluster's calling module for the clusters where you enabled TLS in Kubecost.  
This is done in the `main.tf` file in the root directory of the Terraform module.  
The default value of `tls_verify` is `true`.  
This means that if the `kubecost_api_endpoint` uses an `https` URL and you're using a self-signed certificate in Kubecost, the data collection pod will fail to connect to Kubecost API.  
So in this case, you must disable TLS verification in the data collection pod.  
Please note that although at this point, the data in-transit will be encrypted, using a self-signed certificate is insecure.
3. If your Kubecost frontend container uses a server certificate signed by a CA, the data collection pod will need to pull the CA certificate, so that it can use it for certificate verification.  
Please follow the below steps to add the root CA certificate to the data collection pod:
   1. Add the `kubecost_ca_certificates_list` variable in `common_variables` calling module in the [`main.tf`](terraform/cca_terraform_module/main.tf) file in the root directory of the Terraform module.
   This variable is a list of root CA certificates with the relevant information required for the Terraform module.
   Terraform will use it to create a Secret in AWS Secret Manager.  
   See example for using this variable, in `common_variables` calling module in [the example `main.tf` file](terraform/cca_terraform_module/examples/root_module/main.tf)
   This variable will be used by Terraform to create an AWS Secrets Manager Secret in the pipline account.  
   2. Add the `kubecost_ca_certificate_secret_name` variable to the cluster's calling module for the clusters where you enabled TLS in Kubecost.  
   This is done in the [`main.tf`](terraform/cca_terraform_module/main.tf) file in the root directory of the Terraform module.  
   The value must be the same secret name that you used in the `cert_secret_name` key in the relevant certificate from the `kubecost_ca_certificates_list` variable.  
   This is used by Terraform to identify the secret to be used for the specific cluster to communicate with Kubecost, and pass it to Helm.
   See example for using this variable, in `us-east-1-111111111111-cluster1` calling module in [the example `main.tf` file](terraform/cca_terraform_module/examples/root_module/main.tf).
   3. Add the `kubecost_ca_certificate_secrets` variable to the cluster's calling module for the clusters where you enabled TLS in Kubecost.  
   The value must be `module.pipeline.kubecost_ca_cert_secret`.
   This is done in the [`main.tf`](terraform/cca_terraform_module/main.tf) file in the root directory of the Terraform module.  
   See example for using this variable, in `us-east-1-111111111111-cluster1` calling module in [the example `main.tf` file](terraform/cca_terraform_module/examples/root_module/main.tf).
   4. Make sure that the `tls_verify` variable is `true` (this should be the default)

Once the above procedure is done, the data sent between the data collection pod and Kubecost will be encrypted in-transit.  
Please be advised that all your other clients communicating with Kubecost must now use HTTPS too, and use the said CA certificate.  
Please note that Terraform does not create secret rotation configuration.    
You need to make sure you update the secret with a new CA certificate before it expires. 

[1] The `kubectl` command to use for creating TLS secret:

    kubectl create secret tls <secret_name> --cert=<path_to_cert/cert.pem> --key=<path_to_key/key.pem> -n <namespace> --context <cluster_context>

[2] The values to change in Kubecost Helm chart, to enable TLS:

    kubecostFrontend.tls.enabled=true
    kubecostFrontend.tls.secretName=<secret_name>

[3] Example `helm` command with the TLS flags:

    helm upgrade -i <release_name> oci://public.ecr.aws/kubecost/cost-analyzer --version <version> --namespace <namespace> --create-namespace -f https://raw.githubusercontent.com/kubecost/cost-analyzer-helm-chart/develop/cost-analyzer/values-eks-cost-monitoring.yaml --set kubecostFrontend.tls.enabled=true --set kubecostFrontend.tls.secretName=<secret_name> --kube-context <cluster_context>

[4] Example `kubectl get services` command output:

    kubectl get services -n <namespace> --context <cluster_context>
    NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)            AGE
    kubecost-cost-analyzer            ClusterIP   <ip>             <none>        9003/TCP,443/TCP   199d

## Using an S3 Bucket Policy on the Kubecost Data Bucket

You may create an S3 Bucket Policy on the bucket that you create to store the Kubecost data.  
In this case, below is a recommended bucket policy to use.  
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

This S3 bucket denies all principals from performing all S3 actions, except the principals in the `Condition` section.  
The list of principals shown in the above bucket policy are as follows:

* The `arn:aws:iam::<account_id>:role/<your_bucket_management_role>` principal:  
This principal is an example of an IAM Role you may use to manage the bucket.
Add the IAM Roles that will allow you to perform administrative tasks on the bucket.
* The `arn:aws:iam::<account_id>:role/kubecost_glue_crawler_role` principal:  
This principal is the IAM Role that will be attached to the Glue Crawler when it's created by Terraform.  
You must add it to the bucket policy, so that the Glue Crawler will be able to crawl the bucket.
* The `arn:aws:iam::<account_id>:role/service-role/aws-quicksight-service-role-v0` principal:  
This principal is the IAM Role that will be automatically created for QuickSight.  
If you use a different role, please change it in the bucket policy.  
You must add this role to the bucket policy, for proper functionality of the QuickSight dataset that is created as part of this solution.
* The `aws:PrincipalTag/irsa-kubecost-s3-exporter": "true"` condition:  
This condition identifies all the EKS clusters from which the Kubecost S3 Exporter pod will communicate with the bucket.  
When Terraform creates the IAM roles for the pod to access the S3 bucket, it tags the parent IAM roles with the above tag.  
This tag is automatically being used in the IAM session when the Kubecost S3 Exporter pod authenticates.  
The reason for using this tag is to easily allow all EKS clusters running the Kubecost S3 Exporter pod, in the bucket policy, without reaching the bucket policy size limit.  
The other alternative is to specify all the parent IAM roles that represent each cluster one-by-one.  
With this approach, the maximum bucket policy size will be quickly reached, and that's why the tag is used.

The resources used in this S3 bucket policy include:

* The bucket name, to allow access to it
* All objects in the bucket, using the `arn:aws:s3:::kubecost-data-collection-bucket/*` string.  
The reason for using a wildcard here is that multiple principals (multiple EKS clusters) require access to different objects in the bucket.  
Using specific objects for each principal will result in a longer bucket policy that will eventually exceed the bucket policy size limit.  
The identity policy (the parent IAM role) that is created as part of this solution for each cluster, specifies only the specific prefix and objects.<br >
Considering this, the access to the S3 bucket is more specific than what's specified in the "Resources" part of this bucket policy.

## Setting Server-Side Encryption on the S3 Bucket

It's highly recommended that server-side encryption is set on your S3 Bucket.  
See [this documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-encryption.html) for more information.  
Please note that starting January 5th, 2023, Amazon S3 encrypts new objets by default.  
See [this announcement](https://aws.amazon.com/blogs/aws/amazon-s3-encrypts-new-objects-by-default/) for more information.

## Access to the S3 Bucket

It's advised to block public access to the S3 bucket (see [this document](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)).  
The S3 bucket that stores the Kubecost data is meant to be accessed only from the EKS clusters.  
Also, it's advised to use VPC Endpoints to make sure traffic towards the S3 bucket does not traverse the internet

## AWS Glue Crawler Security Configuration

It's recommended that you create a security configuration for the AWS Glue Crawler.  
In it, it's advised you enable Amazon CloudWatch logs encryption with your CMK.  
See [Working with security configurations on the AWS Glue console](https://docs.aws.amazon.com/glue/latest/dg/console-security-configurations.html)

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
