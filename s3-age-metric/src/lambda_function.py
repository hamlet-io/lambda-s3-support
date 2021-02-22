import os
import urllib
import logging
import boto3

from datetime import date, datetime, timezone
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    '''
    Lists all objects under a bucket and prefix and reports the oldest last modified item (seconds)
    This value is saved as a CloudWatch Metric
    '''

    s3_client = boto3.client('s3')
    cloudwatch_client = boto3.client('cloudwatch')

    bucket_name = os.environ.get('BUCKET_NAME')
    bucket_prefix = os.environ.get('BUCKET_PREFIX', '')
    cloudwatch_metric_namespace = os.environ.get('CLOUDWATCH_METRIC_NAMESPACE', 'S3ObjectAge' )

    now_time = datetime.now(timezone.utc)
    oldest_item = now_time
    oldest_item_key = ''
    continuation_token = ''

    while True:
        try:
            s3_objects = s3_client.list_objects_v2(
                Bucket=bucket_name,
                Prefix=bucket_prefix,
                ContinuationToken=continuation_token,
            )
        except Exception as e:
            logger.fatal(str(e))
            raise e

        s3_contents = sorted(s3_objects["Contents"], key= lambda i: i['LastModified'] )

        oldest_item_in_set = s3_contents[0]['LastModified']
        if oldest_item_in_set < oldest_item:
            oldest_item = oldest_item_in_set
            oldest_item_key = s3_contents[0]['Key']

        if s3_objects['IsTruncated']:
            continuation_token = s3_objects['NextContinuationToken']
        else:
            break

    oldest_item_age = (now_time - oldest_item).seconds

    try:
        cloudwatch_client.put_metric_data(
            Namespace=cloudwatch_metric_namespace,
            MetricData=[
                {
                    'MetricName' : 'OldestModifiedObject',
                    'Dimensions' : [
                        {
                            'Name' : 's3_path',
                            'Value' : f's3://{bucket_name}/{bucket_prefix}'
                        }
                    ],
                    'Timestamp' : now_time,
                    'Value' : oldest_item_age,
                    'Unit' : 'Seconds',
                }
            ]
        )
    except Exception as e:
        logger.fatal(str(e))
        raise e

    logger.info(f'Oldest Item: s3://{bucket_name}/{oldest_item_key} - Age: {oldest_item_age} seconds')
    return {
        'bucket_name': bucket_name,
        'bucket_prefix': bucket_prefix,
        'oldest_item_age': oldest_item_age,
        'oldest_item_key': oldest_item_key
    }
