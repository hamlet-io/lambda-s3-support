[#ftl]

[@addModule
    name="s3_age_metric"
    description="Lambda function which finds the age of the oldest item in a bucket and saves it as a metric"
    provider=S3SUPPORT_PROVIDER
    properties=[
        {
            "Names" : "id",
            "Description" : "A unique id for this instance of the api",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "tier",
            "Description" : "The tier the components will belong to",
            "Types" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "instance",
            "Description" : "The instance id of the components",
            "Types" : STRING_TYPE,
            "Default" : "default"
        },
        {
            "Names" : "bucketLink",
            "Description" : "A link to the bucket you want to monitor",
            "AttributeSet" : LINK_ATTRIBUTESET_TYPE
        },
        {
            "Names" : "bucketPrefix",
            "Description" : "An optional prefix to include in monitoring",
            "Types" : STRING_TYPE,
            "Default" : ""
        },
        {
            "Names" : "cloudwatchNamespace",
            "Description" : "The Namespace to store the metrics under in CloudWatch",
            "Types" : STRING_TYPE,
            "Default" : "S3ObjectAge"
        }
        {
            "Names" : "lambdaImageUrl",
            "Description" : "The url to the lambda zip image",
            "Types" : STRING_TYPE,
            "Default" : "https://github.com/hamlet-io/lambda-s3-support/releases/download/v0.0.16/s3-age-metric.zip"
        },
        {
            "Names" : "lambdaImageHash",
            "Description" : "The sha1 hash of the lambda zip image",
            "Types" : STRING_TYPE,
            "Default" : "f7e70ac8565b0a2b8bc094e4e356b6675d35c946"
        }
    ]
/]


[#macro s3support_module_s3_age_metric
        id
        tier
        instance
        bucketLink
        bucketPrefix
        cloudwatchNamespace
        lambdaImageUrl
        lambdaImageHash
]

    [#local product = getActiveLayer(PRODUCT_LAYER_TYPE) ]
    [#local environment = getActiveLayer(ENVIRONMENT_LAYER_TYPE)]
    [#local segment = getActiveLayer(SEGMENT_LAYER_TYPE)]
    [#local instance = (instance == "default")?then("", instance)]
    [#local namespace = formatName(product["Name"], environment["Name"], segment["Name"])]

    [#local lambdaId = formatName(id, "lambda") ]

    [#local lambdaSettingsNamespace = formatName(namespace, tier, id, instance)]

    [#-- Lambda Configuration --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : lambdaSettingsNamespace,
                "Settings" : {
                    "BUCKET_PREFIX" : bucketPrefix,
                    "CLOUDWATCH_METRIC_NAMESPACE" : cloudwatchNamespace
                }
            }
        ]
    /]

    [#-- Solution Configuration --]
    [@loadModule
        blueprint={
            "Tiers" : {
                tier : {
                    "Components" : {
                        lambdaId : {
                            "lambda": {
                                "deployment:Unit" : lambdaId,
                                "Instances" : {
                                    instance : {}
                                },
                                "Image" : {
                                    "Source" : "url",
                                    "UrlSource" : {
                                        "Url" : lambdaImageUrl,
                                        "ImageHash" : lambdaImageHash
                                    }
                                },
                                "RunTime": "python3.8",
                                "MemorySize": 128,
                                "PredefineLogGroup": true,
                                "VPCAccess": false,
                                "Timeout": 120,
                                "Functions": {
                                    "s3agecheck": {
                                        "Handler": "src/lambda_function.lambda_handler",
                                        "Extensions": [ "_noenv", "_s3_age_metric" ],
                                        "Links" : {
                                            "BUCKET" :
                                                bucketLink +
                                                {
                                                    "Role" : "consume"
                                                }
                                        },
                                        "Schedules" : {
                                            "hourly" : {
                                                "Expression" : "rate(1 hour)"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    /]

[/#macro]
