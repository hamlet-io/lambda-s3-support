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
    [@includeServicesConfiguration
        provider=AWS_PROVIDER
        services=AWS_IDENTITY_SERVICE
        deploymentFramework=CLOUD_FORMATION_DEPLOYMENT_FRAMEWORK
    /]

    [#local links = getLinkTargets(occurrence, {}, false) ]
    [#local s3BatchLambdaId = links["S3_BATCH_JOB_LAMBDA"].State.Resources["function"].Id ]

    [@ContextSetting
        name="S3_BATCH_JOB_LAMBDA_ARN"
        value=getReference(s3BatchLambdaId, ARN_ATTRIBUTE_TYPE)
    /]

    [#local s3BatchRoleId = formatResourceId(AWS_IAM_ROLE_RESOURCE_TYPE, occurrence.Core.Id, "s3", "batchoperations") ]
    [#local s3BatchPolicies = getLinkTargetsOutboundRoles(_context.Links) ]

    [#if deploymentSubsetRequired("iam", true)  &&
                        isPartOfCurrentDeploymentUnit(s3BatchRoleId)]
        [@createRole
                id=s3BatchRoleId
                trustedServices=[
                    "batchoperations.s3.amazonaws.com"
                ]
                policies=[getPolicyDocument(s3BatchPolicies, "links")]
        /]
    [/#if]

    [@ContextSetting
        name="S3_BATCH_ROLE_ARN"
        value=getReference(s3BatchRoleId, ARN_ATTRIBUTE_TYPE)
    /]

    [#-- Allow the S3 event function to pass the IAM role to s3 batch --]
    [@Policy
        iamPassRolePermission(
            [
                getReference(s3BatchRoleId, ARN_ATTRIBUTE_TYPE)
            ]
        )
    /]

    [@Policy
        getPolicyStatement(
            [
                "s3:CreateJob"
            ]
        )
    /]

    [@Settings
        [
            "S3_BATCH_PRIORITY"
        ]
    /]
[/#macro]
