[#ftl]

[@addExtension
    id="s3_inventory_copy_batch"
    aliases=[
        "_s3_inventory_copy_batch"
    ]
    description=[
        "Configures the s3 batch lambda"
    ]
    supportedTypes=[
        LAMBDA_COMPONENT_TYPE,
        LAMBDA_FUNCTION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_s3_inventory_copy_batch_deployment_setup occurrence ]

    [#local s3PathConfig = ((_context.DefaultEnvironment["S3_PATH"])!"")?eval_json ]

    [#local s3DestinationPrefix = ""]
    [#if (s3PathConfig.Prefix.Enabled)!false ]
        [#local s3DestinationPrefix = getContextPath(occurrence, s3PathConfig.Prefix.Path) ]
        [#if s3PathConfig.Prefix.Path.Style == "path" ]
            [#local s3DestinationPrefix = s3DestinationPrefix?ensure_ends_with("/") ]
        [/#if]
    [/#if]

    [#local s3DestinationSuffix = ""]
    [#if (s3PathConfig.Suffix.Enabled)!false ]
        [#local s3DestinationSuffix = getContextPath(occurrence, s3PathConfig.Suffix.Path) ]
        [#if s3PathConfig.Suffix.Path.Style == "path" ]
            [#local s3DestinationSuffix = s3DestinationSuffix?ensure_ends_with("/") ]
        [/#if]
    [/#if]

    [#local destinationBucketLink = _context.Links["DESTINATION_BUCKET"]]
    [#local policyS3DestinationPrefix = s3DestinationPrefix?has_content?then(s3DestinationPrefix, "*" )?remove_ending("/") ]

    [#if destinationBucketLink?has_content ]
        [#local destinationBaselineLinks = getBaselineLinks(destinationBucketLink, ["Encryption" ] )]
        [#local destinationBaselineComponentIds = getBaselineComponentIds(destinationBaselineLinks)]
        [#local destinationKmsKeyId = destinationBaselineComponentIds["Encryption"]]

        [#if (destinationBucketLink.Configuration.Solution.Encryption.Enabled)!false ]
            [@Policy
                s3EncryptionAllPermission(
                    destinationKmsKeyId,
                    destinationBucketLink.State.Attributes["NAME"],
                    policyS3DestinationPrefix,
                    destinationBucketLink.State.Attributes["REGION"]
                )
            /]
        [/#if]

        [@Policy
            s3ProducePermission(destinationBucketLink.State.Attributes["NAME"],  policyS3DestinationPrefix)
        /]
    [/#if]

    [@Settings
        [
            "DESTINATION_BUCKET_NAME",
            "MOVE_OBJECTS"
        ]
    /]

    [@Settings
        {
            "S3_DESTINATION_PREFIX" : s3DestinationPrefix,
            "S3_DESTINATION_SUFFIX" : s3DestinationSuffix
        }
    /]
[/#macro]
