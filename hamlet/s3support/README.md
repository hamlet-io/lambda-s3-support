# S3 Support Plugin

## Description

This plugin provides a collection of utilities to support the management of S3 buckets and their contents in AWS.
The utilities are provided as modules which can be added into your solution as required. Multiple instances are supported for each module allowing you to use each utility as required

The following modules are available in the plugin

| Name               | Description                                                                              |
|--------------------|------------------------------------------------------------------------------------------|
| s3_inventory_copy  | - Enables S3 inventory on an S3 bucket                                                   |
|                    | - A S3 event lambda function which triggers an s3 batch event on new inventory creations |
|                    | - An S3 batch lambda function which will move or copy each item in the batch job         |
| s3_age_metric      | - A lambda function which scans an S3 bucket to find the oldest object                   |
|                    | - the lambda creates a cloud watch metric with the age in seconds of the oldest object   |

## Requirements

### s3-inventory-copy

You must provide an S3 bucket as part of your existing deployment for the source of the inventory
You can optionally provide another s3 bucket for the destination of the move function

### s3_age_metric

You must provide an S3 bucket as part of your existing deployment to scan
A prefix can also be provided to filter the scan


## Usage

A full description of the parameters and types for each module is available under the modules section.

### s3_inventory_copy

Basic setup of the module:

```json
{
  "Modules" : {
    "s3Copy" : {
        "Provider" : "s3support",
        "Name" : "s3_inventory_copy",
        "Enabled" : true,
        "Parameters" : {
            "id" : {
                "Key" : "id",
                "Value" : "<required - string -A unique id for this instance of the api>"
            },
            "tier" : {
                "Key" : "tier",
                "Value" : "<required - string - The tier the components will belong to>"
            },
            "moveObjects" : {
                "Key" : "moveObjects",
                "Value" : "< boolean - Once the file has been copied removed the original"
            },
            "s3KeyPrefix" : {
                "Key" : "s3KeyPrefix",
                "Value" : {
                    "Enabled" : "<boolean - enable s3 key prefix creation>",
                    "Path" : "< instance of contextpath attribute set>"
                }
            },
            "s3KeySuffix" : {
                "Key" : "s3KeySuffix",
                "Value" : {
                    "Enabled" : "<boolean - enable s3 key suffix creation>",
                    "Path" : "< instance of contextpath attribute set>"
                }
            },
            "sourceBucket" : {
                "Key" : "sourceBucketLink",
                "Value" : "<required - instance of link attribute set"
            },
            "destinationBucket" : {
                "Key" : "destinationBucketLink",
                "Value" : "<optional - instance of link attribute set"
            },
            "s3InventoryProfileSuffix" : {
                "Key" : "s3InventoryProfileSuffix",
                "Value" : "<optional - the prefix in the bucket where the inventory will be stored>"
            },
            "lambdaImageUrl" : {
                "Key" : "lambdaImageUrl",
                "Value" : "<optional - The url to the lambda zip image>"
            },
            "lambdaImageHash" : {
                "Key" : "lambdaImageHash",
                "Value" : "<optional - The sha1 hash of the lambda zip image"
            },
            "batchPriorty" : {
                "Key" : "batchPriorty",
                "Value" : "<optional - The priority of the s3 batch call - Highest wins"
            }
        }
    }
  }
}
```

The module creates a deployment profile which should be applied to the bucket listed under sourceBucket
The profile configures inventory reporting and S3 events the name of the profile is formatted as

```<id>_<instance>_<s3InventoryProfileSuffix>```

Where
- id: is the id configured in the instance of the module
- instance: is the instance configured in the in the module instance. If the instance is the default value this won't be included
- s3InventoryProfileSuffix: is the invetory prefix configured in the module instance defaults to `_s3inventorycopy`

### s3_age_metric

Basic module configuration

```json
{
  "Modules" : {
    "s3age" : {
        "Provider" : "s3support",
        "Name" : "s3_age_metric",
        "Enabled" : true,
        "Parameters" : {
            "id" : {
                "Key" : "id",
                "Value" : "<required - string -A unique id for this instance of the api>"
            },
            "tier" : {
                "Key" : "tier",
                "Value" : "<required - string - The tier the components will belong to>"
            },
            "instance" : {
                "Key" : "instance",
                "Value" : "<optional - string - The instance id of the components that will be deployed>"
            },
            "bucketLink" : {
                "Key" : "bucketLink",
                "Value" : "<required - instance of link attribute set - links to the bucket you want to monitor"
            },
            "bucketPrefix" : {
                "Key" : "bucketLink",
                "Value" : "<optional - instance of link attribute set - An optional prefix to include in monitoring"
            },
            "cloudwatchNamespace" : {
                "Key" : "bucketLink",
                "Value" : "<optional - the name of the cloudwatch namespace - default: S3ObjectAge"
            },
            "lambdaImageUrl" : {
                "Key" : "lambdaImageUrl",
                "Value" : "<optional - The url to the lambda zip image>"
            },
            "lambdaImageHash" : {
                "Key" : "lambdaImageHash",
                "Value" : "<optional - The sha1 hash of the lambda zip image"
            }
        }
    }
  }
}
```

## Solution

Each module contributes the following solution content. For more information see the module.ftl file under each module


### s3_inventory_copy

```json
    {
        "Tiers" : {
            <tier> : {
                "Components" : {
                    <lambdaId> : {
                        "Title": "",
                        "lambda": {
                            "deployment:Unit" : <lambdaId>,
                            "Instances" : {
                                <instance> : {}
                            },
                            "Image" : {
                                "Source" : "url",
                                "UrlSource" : {
                                    "Url" : <lambdaImageUrl>,
                                    "ImageHash" : <lambdaImageHash>
                                }
                            },
                            "RunTime": "python3.8",
                            "MemorySize": 128,
                            "PredefineLogGroup": true,
                            "VPCAccess": false,
                            "Timeout": 10,
                            "Functions": {
                                "s3event": {
                                    "Handler": "src/lambda.s3event_lambda_handler",
                                    "Extensions": [ "_noenv", "_s3_inventory_copy_event" ],
                                    "Environment" : {
                                        "Json" : {
                                            "Escaped" : false
                                        }
                                    },
                                    "Links" : {
                                        "S3_BATCH_JOB_LAMBDA" : {
                                            "Tier" : <tier>,
                                            "Component" : <lambdaId>,
                                            "Instance" : <instance>,
                                            "Version" : "",
                                            "Function" : "s3batch",
                                            "Role" : "invoke"
                                        },
                                        "S3_SOURCE" :
                                            <sourceBucketLink> +
                                            {
                                                "Role" : "consume"
                                            }
                                    }
                                },
                                "s3batch": {
                                    "Handler": "src/lambda.s3batch_lambda_handler",
                                    "Extensions": [ "_noenv", "_s3_inventory_copy_batch" ],
                                    "Links" : {
                                        "SOURCE_BUCKET" :
                                            <sourceBucketLink> +
                                            {
                                                "Role" : "consume"
                                            },
                                        "DESTINATION_BUCKET" :
                                            <destinationBucketLink> +
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
            <s3SourceDeploymentProfile> : {
                "Modes" : {
                    "*" : {
                        "s3" : {
                            "Notifications" : {
                                "InventoryCreate" : {
                                    "Links" : {
                                        "s3move_" + <instance> : {
                                            "Tier" : <tier>,
                                            "Component" : <lambdaId>,
                                            "Instance" : <instance>,
                                            "Version" : "",
                                            "Role" : "invoke",
                                            "Function" : "s3event"
                                        }
                                    },
                                    "Prefix" : <s3InventoryPrefix>,
                                    "Suffix" : "manifest.checksum",
                                    "Events" : "create"
                                }
                            },
                            "InventoryReports" : {
                                "IntventoryCopy" : {
                                    "Destination" : {
                                        "Type" : "self"
                                    },
                                    "DestinationPrefix" : <s3InventoryPrefix>
                                }
                            }
                        }
                    }
                }
            }
        }
    }
```
