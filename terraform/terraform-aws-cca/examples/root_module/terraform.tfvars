bucket_arn      = "arn:aws:s3:::bucket-name"
k8s_labels      = ["app", "chart", "component", "app.kubernetes.io/version", "app.kubernetes.io/managed_by", "app.kubernetes.io/part_of"]
k8s_annotations = ["kubernetes.io/psp", "eks.amazonaws.com/compute_type"]
aws_common_tags = {
  tag_key1 = "tag_value1"
  tak_key2 = "tag_value2"
}