resource "aws_iam_policy" "kubecost_glue_policy" {
  name        = local.name
  path        = "/"
  description = "Glue Policy for Kubecost"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "glue:*",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketAcl",
          "cloudwatch:PutMetricData"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${aws_s3_bucket.kubecost_bucket.bucket}/*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
          ],
          "Resource": [
              "arn:aws:logs:*:*:/aws-glue/*"
          ]
      }
    ]
  })
}

resource "aws_iam_role" "kubecost_glue_service_role" {
  name = local.name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
  managed_policy_arns = [aws_iam_policy.kubecost_glue_policy.arn]

}

resource "aws_s3_bucket" "kubecost_bucket" {
  bucket = local.bucket
}

resource "aws_s3_bucket_public_access_block" "s3_block_all_public_access" {
  bucket = aws_s3_bucket.kubecost_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_glue_catalog_database" "glue_kubecost_db" {
  name = local.name
}

resource "aws_glue_crawler" "udid_kubecost_crawler" {
  database_name = aws_glue_catalog_database.glue_kubecost_db.name
  name          = local.name
  role          = aws_iam_role.kubecost_glue_service_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.kubecost_bucket.bucket}"
  }
}