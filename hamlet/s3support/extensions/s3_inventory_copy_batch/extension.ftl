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

    [@Settings
        [
            "DESTINATION_BUCKET_NAME"
        ] +
        valueIfContent(
            [ "S3_DESTINATION_PREFIX" ],
            (_context.DefaultEnvironment["S3_DESTINATION_PREFIX"])!"",
            []
        ) +
        valueIfContent(
            [ "S3_DESTINATION_SUFFIX" ],
            (_context.DefaultEnvironment["S3_DESTINATION_SUFFIX"])!"",
            []
        )
    /]
[/#macro]
