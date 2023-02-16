# Copyright 2022 Amazon.com and its affiliates; all rights reserved.
# This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

import os
import sys
import gzip
import shutil
import logging
import requests
import datetime
import pandas as pd

import boto3
import botocore.exceptions
from boto3 import exceptions

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()

# Environment variables to identify the S3 bucket, Kubecost API endpoint, cluster ID and granularity
S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
KUBECOST_API_ENDPOINT = os.environ.get("KUBECOST_API_ENDPOINT", "http://kubecost-cost-analyzer.kubecost")
CLUSTER_ARN = os.environ["CLUSTER_ARN"]
GRANULARITY = os.environ.get("GRANULARITY", "hourly")
LABELS = os.environ.get("LABELS")


def define_csv_columns(labels):
    """Defines the CSV columns, including static columns, and comma-separated string of K8s labels

    :param labels: Comma-separated string of K8s labels
    :return: List of CSV columns
    """

    # CSV columns definition
    columns = [
        "name",
        "window.start",
        "window.end",
        "minutes",
        "cpuCores",
        "cpuCoreRequestAverage",
        "cpuCoreUsageAverage",
        "cpuCoreHours",
        "cpuCost",
        "cpuCostAdjustment",
        "cpuEfficiency",
        "gpuCount",
        "gpuHours",
        "gpuCost",
        "gpuCostAdjustment",
        "networkTransferBytes",
        "networkReceiveBytes",
        "networkCost",
        "networkCostAdjustment",
        "loadBalancerCost",
        "loadBalancerCostAdjustment",
        "pvBytes",
        "pvByteHours",
        "pvCost",
        "pvCostAdjustment",
        "ramBytes",
        "ramByteRequestAverage",
        "ramByteUsageAverage",
        "ramByteHours",
        "ramCost",
        "ramCostAdjustment",
        "ramEfficiency",
        "sharedCost",
        "externalCost",
        "totalCost",
        "totalEfficiency",
        "rawAllocationOnly",
        "properties.cluster",
        "properties.eksClusterName",
        "properties.container",
        "properties.namespace",
        "properties.pod",
        "properties.node",
        "properties.node_instance_type",
        "properties.node_availability_zone",
        "properties.node_capacity_type",
        "properties.node_architecture",
        "properties.node_os",
        "properties.node_nodegroup",
        "properties.node_nodegroup_image",
        "properties.controller",
        "properties.controllerKind",
        "properties.providerID"
    ]

    if labels:
        labels_columns = ["properties.labels." + x.strip() for x in labels.split(",")]
        return columns + labels_columns
    else:
        return columns


def execute_kubecost_allocation_api(kubecost_api_endpoint, start, end, granularity, aggregate, accumulate=False):
    """Executes Kubecost Allocation API On-demand query.

    :param kubecost_api_endpoint: the Kubecost API endpoint, in format of "http://<ip_or_name>:<port>"
    :param start: the start time for calculating Kubecost Allocation API window
    :param end: the end time for calculating Kubecost Allocation API window
    :param granularity: the user input time granularity, to use for calculating the step (daily or hourly)
    :param aggregate: the K8s object used for aggregation, as per Kubecost Allocation API On-demand query documentation
    :param accumulate: dictates whether to return data for the entire window, or divide to time sets
    :return: the Kubecost Allocation API On-demand query "data" list from the HTTP response
    """

    granularity_map = {
        "hourly": "1h",
        "daily": "1d"
    }

    # Calculate window and step
    window = f'{start.strftime("%Y-%m-%dT%H:%M:%SZ")},{end.strftime("%Y-%m-%dT%H:%M:%SZ")}'
    try:
        step = granularity_map[granularity.lower()]
    except KeyError:
        logger.error("Granularity must be one of 'hourly' or 'daily'")
        sys.exit(1)

    # Executing Kubecost Allocation API call (On-demand query)
    try:
        logger.info(f"Querying Kubecost Allocation On-demand Query API for data between {start} and {end} "
                    f"in {granularity.lower()} granularity...")
        params = {"window": window, "aggregate": aggregate, "accumulate": accumulate, "step": step}
        r = requests.get(f"{kubecost_api_endpoint}/model/allocation/compute", params=params)
        if not r.json()["data"]:
            logger.error("API response appears to be empty.\n"
                         "This script collects data between 72 hours ago and 48 hours ago.\n"
                         "Make sure that you have data at least within this timeframe.")
            sys.exit()

        return r.json()["data"]
    except requests.exceptions.ConnectionError as error:
        logger.error(f"Error connecting to Kubecost Allocation API: {error}")
        sys.exit(1)


def execute_kubecost_assets_api(kubecost_api_endpoint, start, end, accumulate=False):
    """Executes Kubecost Allocation API On-demand query.

    :param kubecost_api_endpoint: the Kubecost API endpoint, in format of "http://<ip_or_name>:<port>"
    :param start: the start time for calculating Kubecost Allocation API window
    :param end: the end time for calculating Kubecost Allocation API window
    :param accumulate: dictates whether to return data for the entire window, or divide to time sets
    :return: the Kubecost Assets API On-demand query "data" list from the HTTP response
    """

    # Calculate window and step
    window = f'{start.strftime("%Y-%m-%dT%H:%M:%SZ")},{end.strftime("%Y-%m-%dT%H:%M:%SZ")}'

    # Executing Kubecost Allocation API call (On-demand query)
    try:
        logger.info(f"Querying Kubecost Assets API for data between {start} and {end}")
        params = {"window": window, "accumulate": accumulate, "filterCategories": "Compute", "filterTypes": "Node"}
        r = requests.get(f"{kubecost_api_endpoint}/model/assets", params=params)
        if not r.json()["data"]:
            logger.error("API response appears to be empty.\n"
                         "This script collects data between 72 hours ago and 48 hours ago.\n"
                         "Make sure that you have data at least within this timeframe.")
            sys.exit()

        return r.json()["data"]
    except requests.exceptions.ConnectionError as error:
        logger.error(f"Error connecting to Kubecost Assets API: {error}")
        sys.exit(1)


def kubecost_allocation_data_add_eks_cluster_name(allocation_data, cluster_arn):
    """Adds the real EKS cluster name from the CLUSTER_ARN input, to each allocation.

    :param allocation_data: the allocation "data" list from Kubecost Allocation API On-demand query HTTP response
    :param cluster_arn: the EKS cluster ARN
    :return: Kubecost allocation data with the real EKS cluster name
    """

    for time_set in allocation_data:
        for allocation in time_set.values():
            if "properties" in allocation.keys():
                if "cluster" in allocation["properties"].keys():
                    allocation["properties"]["eksClusterName"] = cluster_arn.split("/")[-1]

    return allocation_data


def kubecost_allocation_data_add_assets_data(allocation_data, assets_data, cluster_arn):
    """Adds assets data from the Kubecost Assets API to the Kubecost allocation data.

    :param allocation_data: the allocation "data" list from Kubecost Allocation API
    :param assets_data: the asset "data" list from the Kubecost Assets API query HTTP response
    :param cluster_arn: the EKS cluster ARN
    :return: Kubecost allocation data with matching asset data
    """

    cluster_account_id = cluster_arn.split(":")[4]

    for time_set in allocation_data:
        for allocation in time_set.values():
            if "properties" in allocation.keys():
                if "providerID" in allocation["properties"].keys() \
                        and "cluster" in allocation["properties"].keys() \
                        and "node" in allocation["properties"].keys():

                    # Build assets ID from the allocation, to identify the asset in the Assets API response
                    allocation_cluster = allocation["properties"]["cluster"]
                    allocation_provider_id = allocation["properties"]["providerID"]
                    allocation_node = allocation["properties"]["node"]
                    asset_id = f'AWS/{cluster_account_id}/__undefined__/Compute/{allocation_cluster}/Node/Kubernetes/' \
                               f'{allocation_provider_id}/{allocation_node}'

                    # Updating matching asset data from the Assets API, on the allocation properties
                    allocation["properties"]["node_instance_type"] = assets_data[0][asset_id]["nodeType"]
                    allocation["properties"]["node_availability_zone"] = assets_data[0][asset_id]["labels"][
                        "label_topology_kubernetes_io_zone"]
                    allocation["properties"]["node_capacity_type"] = assets_data[0][asset_id]["labels"][
                        "label_eks_amazonaws_com_capacityType"]
                    allocation["properties"]["node_architecture"] = assets_data[0][asset_id]["labels"][
                        "label_kubernetes_io_arch"]
                    allocation["properties"]["node_os"] = assets_data[0][asset_id]["labels"]["label_kubernetes_io_os"]
                    allocation["properties"]["node_nodegroup"] = assets_data[0][asset_id]["labels"][
                        "label_eks_amazonaws_com_nodegroup"]
                    allocation["properties"]["node_nodegroup_image"] = assets_data[0][asset_id]["labels"][
                        "label_eks_amazonaws_com_nodegroup_image"]

    return allocation_data


def kubecost_allocation_data_timestamp_update(allocation_data):
    """Replaces Kubecost's ISO8601 timestamp format to java.sql.Timestamp format, using dictionary comprehension.
    The replacement is necessary due to Athena's requirement for java.sql.Timestamp format.

    :param allocation_data: Kubecost's allocation data (the "data" list from the API response), after any modifications
    :return: A list of lists, where each nested list is a time set with all the unique K8s aggregation values
    """

    allocation_data_with_updated_timestamps = [
        [
            {**d, **{
                "window":
                    {
                        "start": d["window"]["start"].replace("T", " ").replace("Z", ".000"),
                        "end": d["window"]["end"].replace("T", " ").replace("Z", ".000")
                    },
                "start": d["start"].replace("T", " ").replace("Z", ".000"),
                "end": d["end"].replace("T", " ").replace("Z", ".000")
            }
             } for d in y] for y in
        [list(x.values()) for x in allocation_data]
    ]

    return allocation_data_with_updated_timestamps


def kubecost_allocation_data_to_csv(updated_allocation_data, csv_columns):
    """Transforms the Kubecost Allocation data to CSV.

    :param updated_allocation_data: Kubecost's Allocation data after:
     1. Transforming to a nested list
     2. Updating timestamps
    :param csv_columns: the list of columns to use as CSV columns
    :return:
    """

    # DataFrame definition, including all time sets from Kubecost Allocation data
    all_dfs = [pd.json_normalize(x) for x in updated_allocation_data]
    df = pd.concat(all_dfs)

    # Transforming the DataFrame to a CSV and creating the CSV file locally
    df.to_csv("output.csv", sep=",", encoding="utf-8", index=False, quotechar="'", escapechar="\\", columns=csv_columns)


def upload_kubecost_allocation_csv_to_s3(s3_bucket_name, cluster_arn, date, month, year):
    """Compresses and uploads the Kubecost Allocation CSV to an S3 bucket.

    :param s3_bucket_name: the S3 bucket name to use
    :param cluster_arn: the K8s cluster ARN to use for the S3 bucket prefix and CSV file name
    :param date: the date to use in the CSV file name
    :param month: the month to use as part of the S3 bucket prefix
    :param year: the year to use as part of the S3 bucket prefix
    :return:
    """

    cluster_name = cluster_arn.split("/")[-1]
    cluster_account_id = cluster_arn.split(":")[4]
    cluster_region_code = cluster_arn.split(":")[3]

    # Compressing and uploading the CSV file to the S3 bucket
    s3_file_name = "{}_{}".format(date, cluster_name)
    os.rename('output.csv', "{}.csv".format(s3_file_name))
    with open("{}.csv".format(s3_file_name), "rb") as f_in:
        with gzip.open(f"{s3_file_name}.gz", "wb") as f_out:
            shutil.copyfileobj(f_in, f_out)
    try:
        s3 = boto3.resource('s3')
        s3_bucket_prefix = f"account_id={cluster_account_id}/region={cluster_region_code}/year={year}/month={month}"

        logger.info(f"Uploading file {s3_file_name}.gz to S3 bucket {s3_bucket_name}...")
        s3.Bucket(s3_bucket_name).upload_file(f"./{s3_file_name}.gz", f"{s3_bucket_prefix}/{s3_file_name}.gz")
    except boto3.exceptions.S3UploadFailedError as error:
        logger.error(f"Unable to upload file {s3_file_name}.gz to S3 bucket {s3_bucket_name}: {error}")
        sys.exit(1)
    except botocore.exceptions.ClientError as error:
        logger.error(error)
        sys.exit(1)


def kubecost_csv_allocation_data_to_parquet(csv_file_name):
    """Converting Kubecost Allocation data from CSV to Parquet.

    :param csv_file_name: the name of the CSV file
    :return:
    """

    df = pd.read_csv(csv_file_name, encoding='utf8', sep=",", quotechar="'", escapechar="\\")
    df["window.start"] = pd.to_datetime(df["window.start"], format="%Y-%m-%d %H:%M:%S.%f")
    df["window.end"] = pd.to_datetime(df["window.end"], format="%Y-%m-%d %H:%M:%S.%f")
    df.to_parquet("output.snappy.parquet", engine="pyarrow")


def upload_kubecost_allocation_parquet_to_s3(s3_bucket_name, cluster_arn, date, month, year):
    """Compresses and uploads the Kubecost Allocation Parquet to an S3 bucket.

    :param s3_bucket_name: the S3 bucket name to use
    :param cluster_arn: the K8s cluster ARN to use for the S3 bucket prefix and Parquet file name
    :param date: the date to use in the Parquet file name
    :param month: the month to use as part of the S3 bucket prefix
    :param year: the year to use as part of the S3 bucket prefix
    :return:
    """

    cluster_name = cluster_arn.split("/")[-1]
    cluster_account_id = cluster_arn.split(":")[4]
    cluster_region_code = cluster_arn.split(":")[3]

    # Compressing and uploading the Parquet file to the S3 bucket
    s3_file_name = f"{date}_{cluster_name}"
    os.rename("output.snappy.parquet", f"{s3_file_name}.snappy.parquet")
    try:
        s3 = boto3.resource("s3")
        s3_bucket_prefix = f"account_id={cluster_account_id}/region={cluster_region_code}/year={year}/month={month}"

        logger.info(f"Uploading file {s3_file_name}.snappy.parquet to S3 bucket {s3_bucket_name}...")
        s3.Bucket(s3_bucket_name).upload_file(f"./{s3_file_name}.snappy.parquet",
                                              f"{s3_bucket_prefix}/{s3_file_name}.snappy.parquet")
    except boto3.exceptions.S3UploadFailedError as error:
        logger.error(f"Unable to upload file {s3_file_name}.snappy.parquet to S3 bucket {s3_bucket_name}: {error}")
        sys.exit(1)
    except botocore.exceptions.ClientError as error:
        logger.error(error)
        sys.exit(1)


def main():

    # Defining CSV columns
    columns = define_csv_columns(LABELS)

    # Kubecost window definition
    three_days_ago = datetime.datetime.now() - datetime.timedelta(days=3)
    three_days_ago_midnight = three_days_ago.replace(microsecond=0, second=0, minute=0, hour=0)
    three_days_ago_midnight_plus_one_day = three_days_ago_midnight + datetime.timedelta(days=1)
    three_days_ago_date = three_days_ago_midnight.strftime("%Y-%m-%d")
    three_days_ago_year = three_days_ago_midnight.strftime("%Y")
    three_days_ago_month = three_days_ago_midnight.strftime("%m")

    # Executing Kubecost Allocation API call
    kubecost_allocation_data = execute_kubecost_allocation_api(KUBECOST_API_ENDPOINT, three_days_ago_midnight,
                                                               three_days_ago_midnight_plus_one_day, GRANULARITY, "pod")

    kubecost_assets_data = execute_kubecost_assets_api(KUBECOST_API_ENDPOINT, three_days_ago_midnight,
                                                       three_days_ago_midnight_plus_one_day)

    # Adding the real EKS cluster name from the cluster ARN
    kubecost_allocation_data_with_eks_cluster_name = kubecost_allocation_data_add_eks_cluster_name(
        kubecost_allocation_data, CLUSTER_ARN)

    # Assing assets data from the Kubecost Assets API
    kubecost_allocation_data_with_assets_data = kubecost_allocation_data_add_assets_data(
        kubecost_allocation_data_with_eks_cluster_name, kubecost_assets_data, CLUSTER_ARN)

    # Transforming Kubecost's Allocation API data to a list of lists, and updating timestamps
    kubecost_updated_allocation_data = kubecost_allocation_data_timestamp_update(
        kubecost_allocation_data_with_assets_data)

    # Transforming Kubecost's updated allocation data to CSV, then to Parquet, compressing, and uploading it to S3
    kubecost_allocation_data_to_csv(kubecost_updated_allocation_data, columns)
    kubecost_csv_allocation_data_to_parquet("output.csv")
    upload_kubecost_allocation_parquet_to_s3(S3_BUCKET_NAME, CLUSTER_ARN, three_days_ago_date, three_days_ago_month,
                                             three_days_ago_year)


if __name__ == "__main__":
    main()
