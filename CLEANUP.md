# Cleanup

## QuickSight Cleanup - Resources created using `cid-cmd` CLI Tool

1. Log in to QuickSight
2. Manually delete any analysis you created from the dashboard
3. Manually delete the dashboard

## AWS and K8s Resources Cleanup

1. Follow the [Complete Cleanup section in the Terraform module README](terraform/cca_terraform_module/README.md/.#complete-cleanup) file
2. Manually remove the CloudWatch Log Stream that was created by the AWS Glue Crawler
3. Manually empty and delete the S3 bucket you created, if not used for other use-cases

## Helm K8s Resources Cleanup

For clusters on which the K8s resources were deployed using "Deployment Option 2", run the following Helm command per cluster:

    helm uninstall kubecost-s3-exporter -n <namespace> --kube-context <cluster_context>

## Remove Namespaces

For each cluster, remove the namespace by running `kubectl delete ns <namespace> --context <cluster_context>` per cluster.