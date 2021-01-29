import os
import boto3
import urllib
from botocore.exceptions import ClientError


def s3event_lambda_handler(event, context):
    '''
    On S3 Inventory creation events trigger a batch job to work through the inventory
    '''

    s3ControlClient = boto3.client('S3Control')
    s3Client = boto3.client('s3')

    lambda_arn = os.environ('S3_BATCH_JOB_LAMBDA_ARN')
    batch_role_arn = os.environ('S3_BATCH_ROLE_ARN')
    batch_priority = int(os.environ.get('S3_BATCH_PRIORITY', '100'))

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        bucket_arn = record['s3']['bucket']['arn']
        key = unquote_plus(record['s3']['object']['key'])
        event = record['eventName']

        # Only trigger a new batch operation when we have a new checksum
        if key.endswith('manifest.checksum') and event == 'ObjectCreated:Put':

            manifest_key = os.path.splitext(key) + '.json'
            manifest_arn = bucket_arn + os.path.abspath(manifest_key)
            manifest_details = s3Client.head_object(
                Bucket=bucket,
                Key=manifestKey
            )

            manifest_etag = manifest_details.ETag

            job_response = s3ControlClient.create_job(
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
                    'Description' : f'Rename using file suffix - {manifest_key}',
                    'Priority' : batch_priority,
                    'RoleArn' : batch_role_arn
                }
            )


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
    s3Key = urllib.unquote(event['tasks'][0]['s3Key']).decode('utf8')
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
        newKey = rename_key(s3Key)
        newBucket = os.environ('DESTINAION_BUCKET_NAME')

        # Copy Object to New Bucket
        response = s3Client.copy_object(
            CopySource = copySrc,
            Bucket = newBucket,
            Key = newKey
        )

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
            resultString = '{}: {}'.format(errorCode, errorMessage)
    except Exception as e:
        # Catch all exceptions to permanently fail the task
        resultCode = 'PermanentFailure'
        resultString = 'Exception: {}'.format(e.message)
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
        s3_key = os.environ('S3_DESTINATION_PREFIX') + s3_key

    if os.environ.get('S3_DESTINATION_SUFFIX', None):
        s3_key = s3_key + os.environ('S3_DESTINATION_SUFFIX')

    return s3Key + '_new_suffix'
