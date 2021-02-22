# S3 Age Metric

Given an S3 bucket and a prefix this lambda function will create a CloudWatch metric with the oldest item in the bucket

- Metric will be based on seconds old
- Age is based on the LastModified attribute of the object

## Config

All configuration is provided through environment variables

- **BUCKET_NAME** the name of the S3 Bucket
- **BUCKET_PREFIX** an optional prefix in the bucket to determine the age from
- **CLOUDWATCH_METRIC_NAMESPACE** the name of the Cloudwatch namespace to store the metric in ( Default: S3ObjectAge )
