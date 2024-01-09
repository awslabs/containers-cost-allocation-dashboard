output "irsa" {
  description = <<EOF
    A map of IAM Roles that are created for the authentication from the EKS cluster to the AWS resources.
    Below are the descriptions of the map's fields:

    irsa_iam_role_arn: The IRSA IAM Role that is created created when the EKS cluster and the pipeline account are the same.
    In this case, only a IAM Role is created, and this field will be included in the output only in this specific case.

    irsa_child_iam_role: The IRSA child IAM Role that is created when the EKS cluster and the pipeline account are different.
    This is one of two IAM Roles that are created in this case, for cross-account authentication (IAM Role Chaining).
    This field will be included in the output only in case the EKS cluster and the pipeline account are different.

    irsa_parent_iam_role_arn: The IRSA parent IAM Role that is created when the EKS cluster and the pipeline account are different.
    This is one of two IAM Roles that are created in this case, for cross-account authentication (IAM Role Chaining).
    This field will be included in the output only in case the EKS cluster and the pipeline account are different.

  EOF
  value = data.aws_caller_identity.eks_cluster.account_id == data.aws_caller_identity.pipeline.account_id ? {
    irsa_iam_role_arn : aws_iam_role.kubecost_s3_exporter_irsa[0].arn
    } : {
    irsa_child_iam_role : aws_iam_role.kubecost_s3_exporter_irsa_child[0].arn,
    irsa_parent_iam_role_arn : aws_iam_role.kubecost_s3_exporter_irsa_parent[0].arn
  }
}
