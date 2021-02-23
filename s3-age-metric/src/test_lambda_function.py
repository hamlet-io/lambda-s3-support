import os
import time
import mock

import boto3

from datetime import date, datetime, timezone
from moto import mock_s3, mock_cloudwatch

from lambda_function import lambda_handler

@mock_cloudwatch
@mock_s3
def test_no_object_in_bucket():

    bucket_name = 'test_bucket'
    bucket_prefix = ''
    oldest_object_key = 'single_object'

    s3_client = boto3.client('s3', region_name='us-east-1')
    s3_client.create_bucket(Bucket=bucket_name)

    with mock.patch.dict(os.environ, {'BUCKET_NAME': bucket_name, 'BUCKET_PREFIX': bucket_prefix}) as env:
        result = lambda_handler({}, {})

    assert result['bucket_name'] == 'test_bucket'
    assert result['bucket_prefix'] == ''
    assert result['oldest_item_key'] == None

@mock_cloudwatch
@mock_s3
def test_single_object_in_bucket():

    bucket_name = 'test_bucket'
    bucket_prefix = ''
    oldest_object_key = 'single_object'

    s3_client = boto3.client('s3', region_name='us-east-1')
    s3_client.create_bucket(Bucket=bucket_name)
    s3_client.put_object(
        Body='test content',
        Bucket=bucket_name,
        Key=oldest_object_key
    )

    s3_object_details = s3_client.head_object(
        Bucket=bucket_name,
        Key=oldest_object_key
    )
    with mock.patch.dict(os.environ, {'BUCKET_NAME': bucket_name, 'BUCKET_PREFIX': bucket_prefix}) as env:
        result = lambda_handler({}, {})

    assert result['bucket_name'] == 'test_bucket'
    assert result['bucket_prefix'] == ''
    assert result['oldest_item_key'] == 'single_object'


@mock_cloudwatch
@mock_s3
def test_small_set_of_objects_in_bucket():

    bucket_name = 'test_bucket'
    bucket_prefix = ''

    s3_client = boto3.client('s3', region_name='us-east-1')
    s3_client.create_bucket(Bucket=bucket_name)

    # Create a single item first which should be the oldest item
    oldest_object_key = 'oldest_object'
    s3_client.put_object(
        Body='test content',
        Bucket=bucket_name,
        Key=oldest_object_key
    )

    time.sleep(1)

    # Create a lot of items to ensure pagination works as expected
    for i in range(10):
        s3_client.put_object(
            Body='test content',
            Bucket=bucket_name,
            Key=f'object_{i}'
        )

    with mock.patch.dict(os.environ, {'BUCKET_NAME': bucket_name, 'BUCKET_PREFIX': bucket_prefix}) as env:
        result = lambda_handler({}, {})

    assert result['bucket_name'] == 'test_bucket'
    assert result['bucket_prefix'] == ''
    assert result['oldest_item_key'] == 'oldest_object'

@mock_cloudwatch
@mock_s3
def test_large_set_of_objects_in_bucket():

    bucket_name = 'test_bucket'
    bucket_prefix = ''

    s3_client = boto3.client('s3', region_name='us-east-1')
    s3_client.create_bucket(Bucket=bucket_name)

    # Create a single item first which should be the oldest item
    oldest_object_key = 'oldest_object'
    s3_client.put_object(
        Body='test content',
        Bucket=bucket_name,
        Key=oldest_object_key
    )

    time.sleep(1)

    # Create a lot of items to ensure pagination works as expected
    for i in range(2000):
        s3_client.put_object(
            Body='test content',
            Bucket=bucket_name,
            Key=f'object_{i}'
        )

    with mock.patch.dict(os.environ, {'BUCKET_NAME': bucket_name, 'BUCKET_PREFIX': bucket_prefix}) as env:
        result = lambda_handler({}, {})

    assert result['bucket_name'] == 'test_bucket'
    assert result['bucket_prefix'] == ''
    assert result['oldest_item_key'] == 'oldest_object'
