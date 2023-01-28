# Copyright 2022 Amazon.com and its affiliates; all rights reserved.
# This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

import io
import os
import gzip
import logging
import pandas as pd

import boto3

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
DELETE_OBJECTS = os.environ.get("DELETE_OBJECTS")


def main():

    client = boto3.client("s3")
    s3 = boto3.resource("s3")

    # Listing all objects of the Kubecost S3 bucket
    logger.info(f"Listing all objects on S3 bucket {S3_BUCKET_NAME}...")
    objects_list = client.list_objects_v2(Bucket=S3_BUCKET_NAME)

    for s3_object in objects_list["Contents"]:
        if s3_object["Key"].endswith(".gz") and s3_object["Size"] > 0:

            # Parquet file name and S3 bucket prefix definition
            parquet_file_name = s3_object["Key"].split("/")[-1].split(".")[0]
            s3_bucket_prefix = s3_object["Key"].split(parquet_file_name)[0]

            # Getting the object, extracting the body, decompressing it and reading the CSV
            logger.info(f'Getting object {s3_object["Key"]} from S3 bucket {S3_BUCKET_NAME}...')
            allocation_data_gz = client.get_object(Bucket=S3_BUCKET_NAME, Key=s3_object["Key"])
            body = allocation_data_gz["Body"]
            with gzip.GzipFile(fileobj=body) as gzipfile:
                content = gzipfile.read()
            df = pd.read_csv(io.BytesIO(content), encoding='utf8', sep=",", quotechar="'", escapechar="\\")

            # Converting the CSV to Parquet
            logger.info(f"Converting CSV to Parquet...")
            df["window.start"] = pd.to_datetime(df["window.start"], format="%Y-%m-%d %H:%M:%S.%f")
            df["window.end"] = pd.to_datetime(df["window.end"], format="%Y-%m-%d %H:%M:%S.%f")
            df.to_parquet(f"{parquet_file_name}.snappy.parquet", engine="pyarrow")

            # Uploading the Parquet to the S3 bucket
            logger.info(f"Uploading file {parquet_file_name}.snappy.parquet to S3 bucket {S3_BUCKET_NAME}...")
            s3.Bucket(S3_BUCKET_NAME).upload_file(f"./{parquet_file_name}.snappy.parquet",
                                                  f"{s3_bucket_prefix}{parquet_file_name}.snappy.parquet")

            # Deleting the compressed CSV from the S3 bucket
            if DELETE_OBJECTS:
                logger.info(f'Deleting object {s3_object["Key"]} from S3 bucket {S3_BUCKET_NAME}...')
                client.delete_object(Bucket=S3_BUCKET_NAME, Key=s3_object["Key"])


if __name__ == "__main__":
    main()
