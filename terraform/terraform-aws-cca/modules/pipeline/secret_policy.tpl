{
    "Version": "2012-10-17",
    "Statement":
    [
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "secretsmanager:*",
            "Resource": "${arn}",
            "Condition":
            {
                "Bool":
                {
                    "aws:SecureTransport": "false"
                },
                "StringNotEquals":
                {
                    %{ if principals != null }
                        %{ if length(principals) > 0 }
                    "aws:PrincipalTag/irsa-kubecost-s3-exporter-sm": "true",
                    "aws:PrincipalArns": ${jsonencode(principals)}
                        %{ else }
                    "aws:PrincipalTag/irsa-kubecost-s3-exporter-sm": "true"
                        %{ endif }
                    %{ else }
                    "aws:PrincipalTag/irsa-kubecost-s3-exporter-sm": "true"
                    %{ endif }
                }
            }
        }
    ]
}
