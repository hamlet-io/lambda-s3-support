[#ftl]

[@addModule
    name="s3_inventory_copy"
    description="Copies files to a new location based on updates to an S3 inventory report"
    provider=S3SUPPORT_PROVIDER
    properties=[
        {
            "Names" : "id",
            "Description" : "A unique id for this instance of the api",
            "Type" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "tier",
            "Description" : "The tier the components will belong to",
            "Type" : STRING_TYPE,
            "Mandatory" : true
        },
        {
            "Names" : "instance",
            "Description" : "The instance id of the components",
            "Type" : STRING_TYPE,
            "Default" : "default"
        },
        {
            "Names" : "s3KeyPrefix",
            "Description" : "A prefix to append to all keys in the report when copying",
            "Type" : STRING_TYPE,
            "Default" : ""
        },
        {
            "Names" : "s3KeySuffix",
            "Description" : "A suffix to append to all keys in the report when copying",
            "Type" : STRING_TYPE,
            "Default" : ""
        },
        {
            "Names" : "s3InventoryPrefix",
            "Description" : "The prefix to use for inventory generation on the source bucket",
            "Type" : STRING_TYPE,
            "Default" : "s3_inventory_copy/"
        },
        {
            "Names" : "soucrceBucketLink",
            "Description" : "A link to the source s3 bucket which will trigger the copy",
            "Children" : linkChildrenConfiguration
        }
        {
            "Names" : "destinationBucketLink",
            "Description" : "A link to an S3 bucket to copy the report objects to",
            "Children" : linkChildrenConfiguration
        }
        {
            "Names" : "s3InventoryProfileSuffix",
            "Description" : "The suffix ( added to the id ) for the deployment profile which configures the userpool client",
            "Type" : STRING_TYPE,
            "Default" : "_cognitoqs"
        },
        {
            "Names" : "lambdaImageUrl",
            "Description" : "The url to the lambda zip image",
            "Type" : STRING_TYPE,
            "Default" : "https://github.com/hamlet-io/lambda-s3-support/releases/download/v0.0.5/s3-inventory-copy.zip"
        },
        {
            "Names" : "lambdaImageHash",
            "Description" : "The sha1 hash of the lambda zip image",
            "Type" : STRING_TYPE,
            "Default" : "4ecc2684e18be6ad91b704cf211b074919314144"
        },
        {
            "Names" : "batchPriorty",
            "Description" : "The priority of the s3 batch call - Highest wins",
            "Type" : NUMBER_TYPE,
            "Default" : 100
        }
    ]
/]


[#macro s3support_module_s3_inventory_copy
        id
        tier
        instance
        s3KeyPrefix
        s3KeySuffix
        s3InventoryProfileSuffix
        lambdaImageUrl
        lambdaImageHash
        batchPriorty
]

    [#local product = getActiveLayer(PRODUCT_LAYER_TYPE) ]
    [#local environment = getActiveLayer(ENVIRONMENT_LAYER_TYPE)]
    [#local segment = getActiveLayer(SEGMENT_LAYER_TYPE)]
    [#local instance = (instance == "default")?then("", instance)]
    [#local namespace = formatName(product["Name"], environment["Name"], segment["Name"])]

    [#local lambdaId = formatName(id, "lambda") ]
    [#local lambdaSettingsNamespace = formatName(namespace, tier, lambdaId, instance)]


    [#-- Lambda Configuration --]
    [@loadModule
        settingSets=[
            {
                "Type" : "Settings",
                "Scope" : "Products",
                "Namespace" : lambdaSettingsNamespace,
                "Settings" : {
                    "S3_DESTINATION_PREFIX" : s3KeyPrefix,
                    "S3_DESTINATION_SUFFIX" : s3KeySuffix,
                    "S3_BATCH_PRIORITY" : batchPriorty
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
                            "Title": "",
                            "lambda": {
                                "deployment:Unit" : lambdaId,
                                "Image" : {
                                    "Source" : "url",
                                    "UrlSource" : {
                                        "Url" : lambdaImageUrl,
                                        "ImageHash" : lambdaImageHash
                                    }
                                },
                                "RunTime": "python3.6,
                                "MemorySize": 128,
                                "PredefineLogGroup": true,
                                "VPCAccess": false,
                                "Timeout": 10
                                "Functions": {
                                    "s3event": {
                                        "Handler": "src/lambda.s3event_lambda_handler",
                                        "Extensions": [ "_noenv" ],
                                        "Links" : {
                                            "S3_BATCH_JOB_LAMBDA" : {
                                                "Tier" : tier,
                                                "Component" : lambdaId,
                                                "Instance" : instance,
                                                "Version" : "",
                                                "Function" : "s3batch",
                                                "Role" : "invoke"
                                            },
                                            "S3_SOURCE" :
                                                soucrceBucketLink +
                                                {
                                                    "Role" : "consume"
                                                }
                                        }
                                    },
                                    "s3batch": {
                                        "Handler": "src/lambda.s3batch_lambda_handler",
                                        "Extensions": [ "_noenv" ],
                                        "Links" : {
                                            "S3_SOURCE" :
                                                soucrceBucketLink +
                                                {
                                                    "Role" : "consume"
                                                },
                                            "s3_DESTINATION" :
                                                destinationBucketLink +
                                                {
                                                    "Role" : "produce"
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            "DeploymentProfiles" : {
                id + s3InventoryProfileSuffix : {
                    "Modes" : {
                        "*" : {
                            "s3" : {
                                "Notifications" : {
                                    "InventoryCreate" : {
                                        "Links" : {
                                            "s3move" : {
                                                "Tier" : tier,
                                                "Component" : lambdaId,
                                                "Instance" : "",
                                                "Version" : "",
                                                "Role" : "invoke",
                                                "Function" : "s3event"
                                            }
                                        },
                                        "Prefix" : s3InventoryPrefix,
                                        "Suffix" : "manifest.checksum",
                                        "Events" : "create"
                                    }
                                },
                                "InventoryReports" : {
                                    "IntventoryCopy" : {
                                        "Destination" : {
                                            "Type" : "self"
                                        },
                                        "DestinationPrefix" : s3InventoryPrefix
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
