
# CSV to Parquet Converstion Script

This script is used to:

1. Get all gzipped-compressed CSV files from an S3 bucket<br />
2. Convert them to Snappy-compressed Parquet files
3. Ipload the Parquet files back to the S3 bucket
4. Optionally delete the gzipped-compressed CSV files from the S3 bucket

The use-case is for users that used the Kubecost CID integration when it was converting the Kubecost allocation data to CSV, before the change to Parquet.
It's used to provide an automated way of converting all the gzipped-compressed CSV files that are already on the S3 bucket, to Snappy-compressed Parquet files.

## Usage

1. Set the S3_BUCKET_NAME environment variable, with your S3 bucket name
2. If you want to delete the gzipped-compressed CSV files from the S3 bucket, set DELETE_OBJECTS environment variable to any value.
To avoid deleting the gzipped-compressed CSV files from the S3 bucket, do not set the DELETE_OBJECTS at all.