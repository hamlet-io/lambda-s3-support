[#ftl]

[@addExtension
    id="s3_age_metric"
    aliases=[
        "_s3_age_metric"
    ]
    description=[
        "Settings and Permissions for S3 Age Cloudwatch Metrics"
    ]
    supportedTypes=[
        LAMBDA_COMPONENT_TYPE,
        LAMBDA_FUNCTION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_s3_age_metric_deployment_setup occurrence ]

    [@Settings
        [
            "BUCKET_NAME",
            "BUCKET_PREFIX",
            "CLOUDWATCH_METRIC_NAMESPACE"
        ]
    /]

    [#-- Setting available for metric dimensions to lookup --]
    [@Settings
        {
            "S3_PATH" : "s3://${BUCKET_NAME}/${BUCKET_PREFIX}"
        }
    /]

    [#-- CloudWatch Metrics --]
    [#local cloudwatchNamespace = (_context.DefaultEnvironment["CLOUDWATCH_METRIC_NAMESPACE"])!"" ]
    [#if cloudwatchNamespace?has_content ]
        [@Policy
            [
                getPolicyStatement(
                    [
                        "cloudwatch:PutMetricData"
                    ],
                    "*",
                    "",
                    {
                        "StringEquals" : {
                            "cloudwatch:namespace" : cloudwatchNamespace
                        }
                    }
                )
            ]
        /]
    [/#if]
[/#macro]
