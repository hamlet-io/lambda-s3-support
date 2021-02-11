import os
import boto3
import urllib
import logging
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def s3event_lambda_handler(event, context):
    '''
    On S3 Inventory creation events trigger a batch job to work through the inventory
    '''

    s3ControlClient = boto3.client('s3control')
    s3Client = boto3.client('s3')

    lambda_arn = os.environ.get('S3_BATCH_JOB_LAMBDA_ARN')
    batch_role_arn = os.environ.get('S3_BATCH_ROLE_ARN')
    batch_priority = int(os.environ.get('S3_BATCH_PRIORITY', '100'))

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        bucket_arn = record['s3']['bucket']['arn']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'])
        event = record['eventName']

        # Only trigger a new batch operation when we have a new checksum
        if key.endswith('manifest.checksum') and event == 'ObjectCreated:Put':

            logger.info('manfifest checksum file - submitting batch job')
            manifest_key = os.path.splitext(key)[0] + '.json'
            manifest_arn = f'{bucket_arn}/{manifest_key}'

            try:
                manifest_details = s3Client.head_object(
                    Bucket=bucket,
                    Key=manifest_key
                )
                manifest_etag = manifest_details['ETag']

            except Exception as e:
                logger.fatal(str(e))
                raise e

            try:
                job_response = s3ControlClient.create_job(
                    AccountId=boto3.client('sts').get_caller_identity()['Account'],
                    ConfirmationRequired=False,
                    Operation={
                        'LambdaInvoke' : {
                            'FunctionArn' : lambda_arn
                        }
                    },
                    Manifest={
                        'Spec' : {
                            'Format' : 'S3InventoryReport_CSV_20161130',
                        },
                        'Location' : {
                            'ObjectArn' : manifest_arn,
                            'ETag' : manifest_etag
                        },
                    },
                    Report={
                        'Enabled' : False
                    },
                    RoleArn=batch_role_arn,
                    Description=f'Rename using file suffix - {manifest_key}',
                    Priority=batch_priority,
                )
                logger.info(f'batch job id: {job_response["JobId"]}')

            except Exception as e:
                logger.fatal(str(e))
                raise e


def s3batch_lambda_handler(event, context):
    '''
    Appends suffix or prefix to files and also copies to another bucket if required
    '''

    s3Client = boto3.client('s3')

    # Parse job parameters from S3 Batch Operations
    jobId = event['job']['id']
    invocationId = event['invocationId']
    invocationSchemaVersion = event['invocationSchemaVersion']

    # Prepare results
    results = []

    # Parse Amazon S3 Key, Key Version, and Bucket ARN
    taskId = event['tasks'][0]['taskId']
    s3Key = urllib.parse.unquote_plus(event['tasks'][0]['s3Key'])
    s3VersionId = event['tasks'][0]['s3VersionId']
    s3BucketArn = event['tasks'][0]['s3BucketArn']
    s3Bucket = s3BucketArn.split(':::')[-1]

    # Construct CopySource with VersionId
    copySrc = {'Bucket': s3Bucket, 'Key': s3Key}
    if s3VersionId is not None:
        copySrc['VersionId'] = s3VersionId

    # Copy object to new bucket with new key name
    try:
        # Prepare result code and string
        resultCode = None
        resultString = None

        # Construct New Key
        new_key = rename_key(s3Key)
        new_bucket = os.environ.get('DESTINATION_BUCKET_NAME')

        # Copy Object to New Bucket
        response = s3Client.copy_object(
            CopySource = copySrc,
            Bucket = new_bucket,
            Key = new_key
        )
        logger.info(f'Copying file from {copySrc} -> s3://{new_bucket}/{new_key}')

        # Delete the original object if move objects is enabled
        if str(os.environ.get('MOVE_OBJECTS')).lower() == 'true' and response is not None:

            # Avoid copies to the same location from being removed
            if s3Bucket != new_bucket and s3Key != new_key:
                response = s3Client.delete_object(
                    Bucket=s3Bucket,
                    Key=s3Key,
                )
                logger.info(f'removing file s3://{s3Bucket}/{s3Key}')

        # Mark as succeeded
        resultCode = 'Succeeded'
        resultString = str(response)
    except ClientError as e:
        # If request timed out, mark as a temp failure
        # and S3 Batch Operations will make the task for retry. If
        # any other exceptions are received, mark as permanent failure.
        errorCode = e.response['Error']['Code']
        errorMessage = e.response['Error']['Message']
        if errorCode == 'RequestTimeout':
            resultCode = 'TemporaryFailure'
            resultString = 'Retry request to Amazon S3 due to timeout.'
        else:
            resultCode = 'PermanentFailure'
            resultString = f'{errorCode}: {errorMessage}'
        logger.fatal(str(e))
    except Exception as e:
        # Catch all exceptions to permanently fail the task
        resultCode = 'PermanentFailure'
        resultString = f'Exception: {e}'
        logger.fatal(str(e))
    finally:
        results.append({
            'taskId': taskId,
            'resultCode': resultCode,
            'resultString': resultString
        })

    return {
        'invocationSchemaVersion': invocationSchemaVersion,
        'treatMissingKeysAs': 'PermanentFailure',
        'invocationId': invocationId,
        'results': results
    }


def rename_key(s3Key):
    '''
    rename the key by adding additional suffix and/or prefix
    '''

    s3_key = s3Key

    if os.environ.get('S3_DESTINATION_PREFIX', None):
        s3_key = os.environ.get('S3_DESTINATION_PREFIX') + s3_key

    if os.environ.get('S3_DESTINATION_SUFFIX', None):
        s3_key = s3_key + os.environ.get('S3_DESTINATION_SUFFIX')

    return s3_key
