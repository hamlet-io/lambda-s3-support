[#ftl]

[@addExtension
    id="s3_inventory_copy_event"
    aliases=[
        "_s3_inventory_copy_event"
    ]
    description=[
        "Configures the s3 event lambda with batch permissions"
    ]
    supportedTypes=[
        LAMBDA_COMPONENT_TYPE,
        LAMBDA_FUNCTION_COMPONENT_TYPE
    ]
/]

[#macro shared_extension_s3_inventory_copy_event_deployment_setup occurrence ]

    [#-- When submitting an s3 batch we need to give batch an IAM role which allows it to access the source and invoke the lambda --]
    [#-- This creates a new role using the same links as the lambda but with a different trust --]
    [#local s3BatchRoleId = formatResourceId(IAM_ROLE_RESOURCE_TYPE, occurrence.Core.Id, "s3batch") ]
    [#local s3BatchPolicies = getLinkTargetsOutboundRoles(_context.Links) ]
    [@createRole
            id=s3BatchRoleId
            trustedServices=[
                "batchoperations.s3.amazonaws.com"
            ]
            policies=[getPolicyDocument(linkPolicies, "links")]
    /]

    [@Settings
        {
            "S3_BATCH_ROLE_ARN" : getReference(s3BatchRoleId, ARN_ATTRIBUTE_TYPE)
        }
    /]

    [@Settings
        [
            "S3_BATCH_JOB_LAMBDA_ARN",
            "S3_BATCH_PRIORITY"
        ]
    /]
[/#macro]
