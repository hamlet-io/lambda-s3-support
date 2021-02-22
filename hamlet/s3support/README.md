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
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "https://hamlet.io/schema/latest/blueprint/module-s3_inventory_copy-schema.json",
  "definitions": {
    "s3_inventory_copy": {
      "type": "object",
      "patternProperties": {
        "^[A-Za-z_][A-Za-z0-9_]*$": {
          "properties": {
            "id": {
              "type": "string",
              "description": "A unique id for this instance of the api"
            },
            "tier": {
              "type": "string",
              "description": "The tier the components will belong to"
            },
            "instance": {
              "type": "string",
              "description": "The instance id of the components",
              "default": "default"
            },
            "moveObjects": {
              "type": "boolean",
              "description": "Once the file has been copied removed the original",
              "default": false
            },
            "s3KeyPrefix": {
              "type": "object",
              "additionalProperties": false,
              "description": "Creates a key prefix based on the deployment context",
              "properties": {
                "Enabled": {
                  "type": "boolean",
                  "default": true
                },
                "Path": {
                  "$ref": "https://hamlet.io/schema/latest/blueprint/schema-attributeset-schema.json#/contextpath"
                }
              }
            },
            "s3KeySuffix": {
              "type": "object",
              "additionalProperties": false,
              "description": "Creates a key suffix based on the deployment context",
              "properties": {
                "Enabled": {
                  "type": "boolean",
                  "default": false
                },
                "Path": {
                  "$ref": "https://hamlet.io/schema/latest/blueprint/schema-attributeset-schema.json#/contextpath"
                }
              }
            },
            "s3InventoryPrefix": {
              "type": "string",
              "description": "The prefix to use for inventory generation on the source bucket",
              "default": "s3_inventory_copy/"
            },
            "sourceBucketLink": {
              "$ref": "https://hamlet.io/schema/latest/blueprint/schema-attributeset-schema.json#/link",
              "description": "A link to the source s3 bucket which will trigger the copy"
            },
            "destinationBucketLink": {
              "$ref": "https://hamlet.io/schema/latest/blueprint/schema-attributeset-schema.json#/link",
              "description": "A link to an S3 bucket to copy the report objects to"
            },
            "s3InventoryProfileSuffix": {
              "type": "string",
              "description": "The suffix ( added to the id ) for the deployment profile which configures the userpool client",
              "default": "_s3inventorycopy"
            },
            "lambdaImageUrl": {
              "type": "string",
              "description": "The url to the lambda zip image",
              "default": "https://github.com/hamlet-io/lambda-s3-support/releases/download/v0.0.12/s3-inventory-copy.zip"
            },
            "lambdaImageHash": {
              "type": "string",
              "description": "The sha1 hash of the lambda zip image",
              "default": "53c574a946e9146033c9f080ce2c4cbacc205d51"
            },
            "batchPriorty": {
              "type": "number",
              "description": "The priority of the s3 batch call - Highest wins",
              "default": 100
            }
          },
          "additionalProperties": false,
          "required": [
            "id",
            "tier"
          ]
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
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "$id": "https://hamlet.io/schema/latest/blueprint/module-s3_age_metric-schema.json",
  "definitions": {
    "s3_age_metric": {
      "type": "object",
      "patternProperties": {
        "^[A-Za-z_][A-Za-z0-9_]*$": {
          "properties": {
            "id": {
              "type": "string",
              "description": "A unique id for this instance of the api"
            },
            "tier": {
              "type": "string",
              "description": "The tier the components will belong to"
            },
            "instance": {
              "type": "string",
              "description": "The instance id of the components",
              "default": "default"
            },
            "bucketLink": {
              "$ref": "https://hamlet.io/schema/latest/blueprint/schema-attributeset-schema.json#/link",
              "description": "A link to the bucket you want to monitor"
            },
            "bucketPrefix": {
              "type": "string",
              "description": "An optional prefix to include in monitoring"
            },
            "cloudwatchNamespace": {
              "type": "string",
              "description": "The Namespace to store the metrics under in CloudWatch",
              "default": "S3ObjectAge"
            },
            "lambdaImageUrl": {
              "type": "string",
              "description": "The url to the lambda zip image",
              "default": "https://github.com/hamlet-io/lambda-s3-support/releases/download/v0.0.12/s3-age-metric.zip"
            },
            "lambdaImageHash": {
              "type": "string",
              "description": "The sha1 hash of the lambda zip image",
              "default": "53c574a946e9146033c9f080ce2c4cbacc205d51"
            }
          },
          "additionalProperties": false,
          "required": [
            "id",
            "tier"
          ]
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


### s3_age_metric

```json
    {
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
```
