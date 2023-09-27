# Copyright 2023 Amazon.com and its affiliates; all rights reserved.
# This file is Amazon Web Services Content and may not be duplicated or distributed without permission.

import os
import re
import sys
import logging
import requests
import datetime
import pandas as pd

import boto3
import botocore.exceptions
from boto3 import exceptions

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("kubecost-s3-exporter")

# Mandatory environment variables, and input validations
try:
    S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
    if not re.match(r"(?!(^xn--|.+-s3alias$))(^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$)", S3_BUCKET_NAME):
        logger.error(f"The 'S3_BUCKET_NAME' input contains an invalid S3 Bucket name: {S3_BUCKET_NAME}")
        sys.exit(1)
    if re.match(r".*\d{12}.*|.*(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\d.*",
                S3_BUCKET_NAME):
        logger.warning("The S3 Bucket name includes an AWS account ID or a region-code. "
                       "This could lead to bucket sniping. "
                       "It's advised to use an S3 Bucket name that doesn't include an AWS account ID or a region-code")
except KeyError:
    logger.error("The 'S3_BUCKET_NAME' input is a required, but it's missing")
    sys.exit(1)

try:
    CLUSTER_ID = os.environ["CLUSTER_ID"]
    if not re.match(r"^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\d:\d{12}:cluster/[a-zA-Z0-9][a-zA-Z0-9-_]{1,99}$", CLUSTER_ID):
        logger.error(f"The 'CLUSTER_ID' input contains an invalid EKS cluster ARN: {CLUSTER_ID}")
        sys.exit(1)
except KeyError:
    logger.error("The 'CLUSTER_ID' input is a required, but it's missing")
    sys.exit(1)

# Optional environment variables, and input validations

IRSA_PARENT_IAM_ROLE_ARN = os.environ["IRSA_PARENT_IAM_ROLE_ARN"]
if IRSA_PARENT_IAM_ROLE_ARN:
    if not re.match(r"^arn:(?:aws|aws-cn|aws-us-gov):iam::\d{12}:role/[a-zA-Z0-9+=,.@_-]{1,64}$",
                    IRSA_PARENT_IAM_ROLE_ARN):
        logger.error(f"The 'IRSA_PARENT_IAM_ROLE_ARN' input contains an invalid ARN: {IRSA_PARENT_IAM_ROLE_ARN}")
        sys.exit(1)


KUBECOST_API_ENDPOINT = os.environ.get("KUBECOST_API_ENDPOINT", "http://kubecost-cost-analyzer.kubecost:9090")
if not re.match(r"^https?://.+$", KUBECOST_API_ENDPOINT):
    logger.error("The Kubecost API endpoint is invalid. It must be in the format of "
                 "'http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]'")
    sys.exit(1)

try:
    BACKFILL_PERIOD_DAYS = int(os.environ.get("BACKFILL_PERIOD_DAYS", 15))
    if BACKFILL_PERIOD_DAYS < 3:
        logger.error("The BACKFILL_PERIOD_DAYS input must be a positive integer equal to or larger than 3")
        sys.exit(1)
except ValueError:
    logger.error("The BACKFILL_PERIOD_DAYS input must be an integer")
    sys.exit(1)

AGGREGATION = os.environ.get("AGGREGATION", "container")
if AGGREGATION not in ["container", "pod", "namespace", "controller", "controllerKind", "node", "cluster"]:
    logger.error("Aggregation must be one of "
                 "'container', 'pod', 'namespace', 'controller', 'controllerKind', 'node', or 'cluster'")
    sys.exit(1)

KUBECOST_ALLOCATION_API_PAGINATE = os.environ.get("KUBECOST_ALLOCATION_API_PAGINATE", "False").lower()
if KUBECOST_ALLOCATION_API_PAGINATE not in ["yes", "no", "y", "n", "true", "false"]:
    logger.error("The 'KUBECOST_ALLOCATION_API_PAGINATE' input must be one of "
                 "'Yes', 'No', 'Y', 'N', 'True' or 'False' (case-insensitive)")
    sys.exit(1)

try:
    CONNECTION_TIMEOUT = float(os.environ.get("CONNECTION_TIMEOUT", 10))
    if CONNECTION_TIMEOUT <= 0:
        logger.error("The connection timeout must be a non-zero positive integer")
        sys.exit(1)
except ValueError:
    logger.error("The connection timeout must be a float")
    sys.exit(1)

try:
    KUBECOST_ALLOCATION_API_READ_TIMEOUT = float(os.environ.get("KUBECOST_ALLOCATION_API_READ_TIMEOUT", 60))
    if KUBECOST_ALLOCATION_API_READ_TIMEOUT <= 0:
        logger.error("The read timeout must be a non-zero positive float")
        sys.exit(1)
except ValueError:
    logger.error("The read timeout must be a float")
    sys.exit(1)

TLS_VERIFY = os.environ.get("TLS_VERIFY", "True").lower()
if TLS_VERIFY in ["yes", "y", "true"]:
    TLS_VERIFY = True
elif TLS_VERIFY in ["no", "n", "false"]:
    TLS_VERIFY = False
else:
    logger.error("The 'TLS_VERIFY' input must be one of 'Yes', 'No', 'Y', 'N', 'True' or 'False' (case-insensitive)")
    sys.exit(1)

KUBECOST_CA_CERTIFICATE_SECRET_NAME = os.environ.get("KUBECOST_CA_CERTIFICATE_SECRET_NAME")
if KUBECOST_CA_CERTIFICATE_SECRET_NAME:
    if not re.match(r"^[a-z[A-Z0-9/_+=.@-]{1,512}$", KUBECOST_CA_CERTIFICATE_SECRET_NAME):
        logger.error("The 'KUBECOST_CA_CERTIFICATE_SECRET_NAME' input contains an invalid secret name: "
                     f"{KUBECOST_CA_CERTIFICATE_SECRET_NAME}")
        sys.exit(1)

KUBECOST_CA_CERTIFICATE_SECRET_REGION = os.environ.get("KUBECOST_CA_CERTIFICATE_SECRET_REGION")
if KUBECOST_CA_CERTIFICATE_SECRET_REGION:
    if not re.match(r"^(us(-gov)?|ap|ca|cn|eu|sa)-(central|(north|south)?(east|west)?)-\d$",
                    KUBECOST_CA_CERTIFICATE_SECRET_REGION):
        logger.error("The 'KUBECOST_CA_CERTIFICATE_SECRET_REGION' input contains an invalid region code: "
                     f"{KUBECOST_CA_CERTIFICATE_SECRET_REGION}")
        sys.exit(1)

LABELS = os.environ.get("LABELS")
if LABELS:
    if not re.match(
            r"^((([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])/[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]|[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]+)(,\s*[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]|(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])/[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]+)+$",
            LABELS):
        logger.error("At least one of the items the 'LABELS' list, contains an invalid K8s label key")
        sys.exit(1)
ANNOTATIONS = os.environ.get("ANNOTATIONS")
if ANNOTATIONS:
    if not re.match(
            r"^((([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])/[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]|[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]+)(,\s*[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]|(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9-]*[A-Za-z0-9])/[a-zA-Z0-9][-A-Za-z0-9_.]{0,61}[a-zA-Z0-9]+)+$",
            ANNOTATIONS):
        logger.error("At least one of the items the 'ANNOTATIONS' list, contains an invalid K8s annotation key")
        sys.exit(1)


def create_kubecost_labels_to_k8s_labels_mapping(labels):
    """Creates a dict of the K8s labels keys as they're seen in Kubecost API response, to the original K8s labels keys.
    It's because Kubecost reports K8s labels with underscores replacing dot, forward-slash and hyphen characters.
    In the destination dataset (Athena), we'd like the labels columns to show the original K8s labels keys.

    :param labels: A comma-separated list of the original K8s labels keys as they were given by the user input.
    :return: A dict mapping the Kubecost representation of K8s labels keys, to the original K8s labels keys
    """

    kubecost_labels_to_orig_labels = {}

    if labels:
        labels_columns_kubecost = ["properties.labels." + re.sub(r"[./-]", "_", x.strip()) for x in labels.split(",")]
        labels_columns_orig = ["properties.labels." + x.strip() for x in labels.split(",")]
        kubecost_labels_to_orig_labels = dict(zip(labels_columns_kubecost, labels_columns_orig))

    return kubecost_labels_to_orig_labels


def create_kubecost_annotations_to_k8s_annotations_mapping(annotations):
    """Creates a dict of the K8s annotations as they're seen in Kubecost API response, to the original K8s annotations.
    It's because Kubecost reports K8s annotations with underscores replacing dot, forward-slash and hyphen characters.
    In the destination dataset (Athena), we'd like the annotations columns to show the original K8s annotations.

    :param annotations: A comma-separated list of the original K8s annotations as they were given by the user input.
    :return: A dict mapping the Kubecost representation of K8s annotations, to the original K8s annotations
    """

    kubecost_annotations_to_orig_annotations = {}

    if annotations:
        annotations_columns_kubecost = ["properties.annotations." + re.sub(r"[./-]", "_", x.strip()) for x in
                                        annotations.split(",")]
        annotations_columns_orig = ["properties.annotations." + x.strip() for x in annotations.split(",")]
        kubecost_annotations_to_orig_annotations = dict(zip(annotations_columns_kubecost, annotations_columns_orig))

    return kubecost_annotations_to_orig_annotations


def define_dataframe_columns(kubecost_labels_to_orig_labels, kubecost_annotations_to_orig_annotations):
    """Defines the DataFrame columns and their mapping to default missing value.

    :param kubecost_labels_to_orig_labels: A dict of Kubecost K8s labels keys, to original K8s labels keys
    :param kubecost_annotations_to_orig_annotations: A dict of Kubecost K8s annotations, to original K8s annotations
    :return: Dictionary of DataFrame columns mapped to their NA/NaN value.
    This is including columns for K8s label keys and annotations, the way they're represented in Kubecost.
    """

    # DataFrame columns definition
    dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations = {
        "name": "",
        "window.start": "",
        "window.end": "",
        "minutes": 0,
        "cpuCores": 0,
        "cpuCoreRequestAverage": 0,
        "cpuCoreUsageAverage": 0,
        "cpuCoreHours": 0,
        "cpuCost": 0,
        "cpuCostAdjustment": 0,
        "cpuEfficiency": 0,
        "gpuCount": 0,
        "gpuHours": 0,
        "gpuCost": 0,
        "gpuCostAdjustment": 0,
        "networkTransferBytes": 0,
        "networkReceiveBytes": 0,
        "networkCost": 0,
        "networkCrossZoneCost": 0,
        "networkCrossRegionCost": 0,
        "networkInternetCost": 0,
        "networkCostAdjustment": 0,
        "loadBalancerCost": 0,
        "loadBalancerCostAdjustment": 0,
        "pvBytes": 0,
        "pvByteHours": 0,
        "pvCost": 0,
        "pvCostAdjustment": 0,
        "ramBytes": 0,
        "ramByteRequestAverage": 0,
        "ramByteUsageAverage": 0,
        "ramByteHours": 0,
        "ramCost": 0,
        "ramCostAdjustment": 0,
        "ramEfficiency": 0,
        "sharedCost": 0,
        "externalCost": 0,
        "totalCost": 0,
        "totalEfficiency": 0,
        "properties.provider": "",
        "properties.region": "",
        "properties.cluster": "",
        "properties.clusterid": "",
        "properties.eksClusterName": "",
        "properties.container": "",
        "properties.namespace": "",
        "properties.pod": "",
        "properties.node": "",
        "properties.node_instance_type": "",
        "properties.node_availability_zone": "",
        "properties.node_capacity_type": "",
        "properties.node_architecture": "",
        "properties.node_os": "",
        "properties.node_nodegroup": "",
        "properties.node_nodegroup_image": "",
        "properties.controller": "",
        "properties.controllerKind": "",
        "properties.providerID": "",
        "properties.labels.eks_amazonaws_com_capacityType": "",
        "properties.labels.karpenter_sh_capacity_type": "",
        "properties.labels.eks_amazonaws_com_nodegroup": "",
        "properties.labels.karpenter_sh_provisioner_name": "",
        "properties.labels.eks_amazonaws_com_nodegroup_image": "",
        "properties.labels.karpenter_k8s_aws_instance_ami_id": ""
    }

    if kubecost_labels_to_orig_labels:
        for kubecost_label in kubecost_labels_to_orig_labels.keys():
            dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations[kubecost_label] = ""
    if kubecost_annotations_to_orig_annotations:
        for kubecost_annotations in kubecost_annotations_to_orig_annotations.keys():
            dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations[kubecost_annotations] = ""

    return dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations


def iam_assume_role(iam_role_arn, iam_role_session_name):
    """Assumes an IAM Role, to be used on all AWS API calls.

    :param iam_role_arn: The ARN of the IAM Role to be assumed.
    :param iam_role_session_name: The IAM session name.
    :return: The Assume Role API call response
    """

    try:
        sts = boto3.client("sts")
        response = sts.assume_role(RoleArn=iam_role_arn, RoleSessionName=iam_role_session_name)

        return response
    except botocore.exceptions.ClientError as error:
        logger.error(error)
        sys.exit(1)


def secrets_manager_get_secret_value(secret_name, region_code, assume_role_response):
    """Retrieves secret's value from Secret Manager.

    :param secret_name: The AWS Secrets Manager Secret name
    :param region_code: The region-code to be used when making the secretsmanager:GetSecretValue API call
    :param assume_role_response: The response of the sts:AssumeRole API call that was made prior to this API call
    :return: The secret string from the API call's response
    """

    try:
        # Client definition in case the EKS cluster and AWS Secrets Manager are in different AWS accounts.
        # This means cross account authentication will be done, so the client contains the parent IAM role credentials
        if assume_role_response:
            client = boto3.client("secretsmanager", aws_access_key_id=assume_role_response["Credentials"]["AccessKeyId"],
                                  aws_secret_access_key=assume_role_response["Credentials"]["SecretAccessKey"],
                                  aws_session_token=assume_role_response["Credentials"]["SessionToken"],
                                  region_name=region_code)

        # Client definition in case the EKS cluster and AWS Secrets Manager are in the same AWS account.
        # This means cross account authentication isn't necessary, so IRSA credentials will be used
        else:
            client = boto3.client("secretsmanager", region_name=region_code)
        logger.info(f"Retrieving secret '{secret_name}' from AWS Secrets Manager...")

        response = client.get_secret_value(SecretId=secret_name)
        secret_value = response["SecretString"]

        return secret_value
    except botocore.exceptions.ClientError as error:
        logger.error(error)
        sys.exit(1)


def create_ca_cert_file(ca_cert_string):
    """Creates a CA certificate file from the content of a CA certificate.

    :param ca_cert_string: The CA certificate string (not file)
    :return:
    """

    cat_cert_file = open("/tmp/ca.cert.pem", "a")
    cat_cert_file.write(ca_cert_string)
    cat_cert_file.close()


def kubecost_backfill_period_window_calc(backfill_period_days):
    """Calculates the window to use for querying Kubecost API to get available dates for the backfill period.
    This is as part of the backfill logic.

    :param backfill_period_days: The backfill period in days
    :return: Returns the following:
    backfill_start_date_midnight: The window start to query Kubecost Allocation API
    backfill_end_date_midnight: The window end to query Kubecost Allocation API
    """

    # Calculating the window for Kubecost Allocation API call to retrieve
    backfill_period_hours = backfill_period_days * 24
    kubecost_last_datetime = datetime.datetime.now() - datetime.timedelta(hours=backfill_period_hours)
    backfill_start_date = kubecost_last_datetime + datetime.timedelta(days=1)
    backfill_start_date_midnight = backfill_start_date.replace(microsecond=0, second=0, minute=0, hour=0)
    backfill_end_date = datetime.datetime.now() - datetime.timedelta(days=2)
    backfill_end_date_midnight = backfill_end_date.replace(microsecond=0, second=0, minute=0, hour=0)

    return backfill_start_date_midnight, backfill_end_date_midnight


def get_kubecost_backfill_period_available_dates(allocation_data):
    """Extracts the available dates for the backfill period, from Kubecost Allocation API response.

    :param allocation_data: The allocation "data" list from Kubecost Allocation API response
    :return: A dictionary with the available dates for the backfill period, along with the time window for each date
    """

    # Iterating over each timeset and retrieving the window
    # Then, creating a dictionary mapping the timeset date to the window
    kubecost_backfill_period_available_dates = {}
    for timeset in allocation_data:
        date = {timeset[next(iter(timeset))]["window"]["start"].split("T")[0]: timeset[next(iter(timeset))]["window"]}
        kubecost_backfill_period_available_dates.update(date)

    return kubecost_backfill_period_available_dates


def get_s3_backfill_period_available_dates(s3_bucket_name, cluster_id, backfill_period_days, assume_role_response):
    """Retrieving the Kubecost allocation data dates that are available as Parquet files in S3.
    This is done as per the following process:
    1. Executing s3:ListObjectsV2 to get the available objects for the cluster, for the backfill period only.
    2. Extracting the Kubecost allocation data date from the name of each Parquet file
    3. Creating a list of the dates

    :param s3_bucket_name: The S3 bucket name to use
    :param cluster_id: The cluster ID to use for the S3 bucket prefix and Parquet file name
    :param backfill_period_days: The backfill period in days
    :param assume_role_response: The Assume Role API call response
    :return: A list of the Kubecost allocation data dates that are available as Parquet files in the S3 bucket
    """

    # Removing the environment variable that is used to specify customer root CA certificate for the Kubecost API
    # This is so that Python will use the default CA bundle
    try:
        del os.environ["REQUESTS_CA_BUNDLE"]
    except KeyError:
        pass

    # Extracting EKS cluster ARN, account ID and region
    cluster_name = cluster_id.split("/")[-1]
    cluster_account_id = cluster_id.split(":")[4]
    cluster_region_code = cluster_id.split(":")[3]

    # Defining the date and time pieces that will be used in the "StartAfter" input
    # This is done so that only the objects relevant for the backfill period will be listed
    backfill_period_hours = backfill_period_days * 24
    kubecost_last_datetime = datetime.datetime.now() - datetime.timedelta(hours=backfill_period_hours)
    backfill_start_date = kubecost_last_datetime + datetime.timedelta(days=1)
    start_after_datetime = backfill_start_date - datetime.timedelta(days=1)
    start_after_date = start_after_datetime.strftime("%Y-%m-%d")
    start_after_year = start_after_datetime.strftime("%Y")
    start_after_month = start_after_datetime.strftime("%m")

    # Based on the above date and time pieces and EKS cluster ARN pieces, the prefix and file name are defined
    # Then, they're used as the key specified in the "StartAfter" input
    # In addition, the prefix respose limit is defined
    s3_prefix = f"account_id={cluster_account_id}/region={cluster_region_code}/year={start_after_year}/month={start_after_month}"
    s3_file_name = f"{start_after_date}_{cluster_name}.snappy.parquet"
    s3_list_object_v2_start_after = f"{s3_prefix}/{s3_file_name}"
    s3_list_object_v2_prefix_response_limit = f"account_id={cluster_account_id}/region={cluster_region_code}/"

    # Executing the s3:ListObjectsV2 API call
    try:
        # Client definition in case the EKS cluster and AWS Secrets Manager are in different AWS accounts.
        # This means cross account authentication will be done, so the client contains the parent IAM role credentials
        if assume_role_response:
            client = boto3.client("s3", aws_access_key_id=assume_role_response["Credentials"]["AccessKeyId"],
                                  aws_secret_access_key=assume_role_response["Credentials"]["SecretAccessKey"],
                                  aws_session_token=assume_role_response["Credentials"]["SessionToken"])

        # Client definition in case the EKS cluster and AWS Secrets Manager are in the same AWS account.
        # This means cross account authentication isn't necessary, so IRSA credentials will be used
        else:
            client = boto3.client("s3")
        logger.info(f"Retrieving list of objects for cluster '{cluster_id}' in the last {backfill_period_days} "
                    f"days from S3 Bucket '{s3_bucket_name}'...")
        paginator = client.get_paginator("list_objects_v2")
        response = paginator.paginate(Bucket=s3_bucket_name, StartAfter=s3_list_object_v2_start_after,
                                      Prefix=s3_list_object_v2_prefix_response_limit)
    except botocore.exceptions.ClientError as error:
        logger.error(error)
        sys.exit(1)

    # Extracting the available dates for the backfill period
    try:
        cluster_s3_keys_for_backfill_period = []

        # Paginating through the response pages, and consolidating all relevant keys to a single list
        for page in response:
            for s3_object in page["Contents"]:

                # The below condition addresses the following scenario:
                # Given the objects prefix and filename structure, we can't filter the list in the API call level
                # Even that we use "StartAfter" and "Prefix" inputs, other clusters objects can be returned
                # Therefore, we only the keys that include the given cluster name are extracted from each page
                # They're then added to a consolidated list of all keys that include the cluster name, in all pages
                if cluster_name in s3_object["Key"]:
                    cluster_s3_keys_for_backfill_period.append(s3_object["Key"])

        # If items S3 keys are found in the consolidated list, the date portion is extracted from each one of them.
        # This date represents the date when the data was collected by Kubecost
        # If the consolidated list is empty, we return an empty list.
        # This means there's no Kubecost data for this cluster for the given backfill period
        if cluster_s3_keys_for_backfill_period:
            cluster_s3_files_for_backfill_period = [s3_key.split("/")[-1] for s3_key in
                                                    cluster_s3_keys_for_backfill_period]
            cluster_s3_available_dates_for_backfill_period = [s3_file.split("_")[0] for s3_file in
                                                              cluster_s3_files_for_backfill_period]
            return cluster_s3_available_dates_for_backfill_period
        else:
            logger.info(f"There are objects in S3 Bucket '{s3_bucket_name}' in the requested backfill period "
                        f"({backfill_period_days} days ago), but no objects found for cluster '{cluster_id}'")
            return []

    # Catching scenario where there are no objects at all based on the "StartAfter" and "Prefix" filters in the API call
    except KeyError:
        logger.info(f"No objects found in S3 Bucket '{s3_bucket_name}' in the requested backfill period "
                    f"({backfill_period_days} days ago) for cluster '{cluster_id}'")
        return []


def calc_kubecost_dates_missing_from_s3(kubecost_backfill_period_available_dates, s3_backfill_period_available_dates):
    """Calculates the Kubecost available dates, that are missing from S3, for the backfill period.
    This is based on the following set of data:
    1. The available dates that were extracted from Kubecost Allocation API
    2. The Kubecost allocation data available dates in S3

    :param kubecost_backfill_period_available_dates: The available dates in Kubecost Allocation API
    :param s3_backfill_period_available_dates: The Kubecost allocation data dates that are available in S3
    :return: A dictionary with the missing dates from S3, for the backfill period, mapped to the time window
    """

    # Comparing the Kubecost available dates to the dates available in S3
    # The result is a dictionary with:
    # The missing dates from S3, for the backfill period, mapped to the time window
    kuebcost_dates_missing_from_s3 = {date: window for (date, window) in
                                      kubecost_backfill_period_available_dates.items() if
                                      date not in s3_backfill_period_available_dates}
    if kuebcost_dates_missing_from_s3:
        logger.info(f"Found missing Kubecost data in S3 for dates {', '.join(kuebcost_dates_missing_from_s3)}")
        return kuebcost_dates_missing_from_s3
    else:
        logger.info("All dates for Kubecost data for the backfill period, are available in S3. No collection needed")


def execute_kubecost_allocation_api(tls_verify, kubecost_api_endpoint, start, end, granularity, aggregate,
                                    connection_timeout, read_timeout, paginate, idle, split_idle, idle_by_node,
                                    share_tenancy_costs, accumulate):
    """Executes Kubecost Allocation API.

    :param tls_verify: Dictates whether TLS certificate verification is done for HTTPS connections
    :param kubecost_api_endpoint: The Kubecost API endpoint, in format of "http://<ip_or_name>:<port>"
    :param start: The start time for calculating Kubecost Allocation API window
    :param end: The end time for calculating Kubecost Allocation API window
    :param granularity: The user input time granularity, to use for calculating the step (daily or hourly)
    :param aggregate: The K8s object used for aggregation, as per Kubecost Allocation API documentation
    :param connection_timeout: The timeout (in seconds) to wait for TCP connection establishment
    :param read_timeout: The timeout (in seconds) to wait for the server to send an HTTP response
    :param paginate: Dictates whether to paginate using 1-hour time ranges (relevant for "1h" step)
    :param idle: Dictates whether to include idle costs
    :param split_idle: Dictates if idle allocations are split (per node or cluster), or aggregated into a single idle
    :param idle_by_node: When "split_idle" is "True", dictates if idle allocations are split by node or cluster
    :param share_tenancy_costs: Dictates whether to include shared tenancy costs in the "sharedCost" field
    :param accumulate: Dictates whether to return data for the entire window, or divide to time sets
    :return: The Kubecost Allocation API "data" list from the HTTP response
    """

    if KUBECOST_CA_CERTIFICATE_SECRET_NAME:
        os.environ["REQUESTS_CA_BUNDLE"] = "/tmp/ca.cert.pem"

    # Setting the step
    step = "1h" if granularity == "hourly" else "1d"

    # Executing Kubecost Allocation API call
    try:

        # If the step is "1h" and pagination is true, the API call is executed for each hour in the 24-hour timeframe
        # This is to prevent OOM in the Kubecost/Prometheus containers, and to avoid using high read-timeout value
        if step == "1h" and paginate in ["yes", "y", "true"]:

            data = []
            for n in range(1, 25):

                start_h = start + datetime.timedelta(hours=n - 1)
                end_h = start + datetime.timedelta(hours=n)

                # Calculating the window and defining the API call requests parameters
                window = f'{start_h.strftime("%Y-%m-%dT%H:%M:%SZ")},{end_h.strftime("%Y-%m-%dT%H:%M:%SZ")}'
                if aggregate == "container":
                    params = {"window": window, "accumulate": accumulate, "step": step, "idle": idle,
                              "splitIdle": split_idle, "idleByNode": idle_by_node,
                              "shareTenancyCosts": share_tenancy_costs}
                else:
                    params = {"window": window, "aggregate": aggregate, "accumulate": accumulate, "step": step,
                              "idle": idle, "splitIdle": split_idle, "idleByNode": idle_by_node,
                              "shareTenancyCosts": share_tenancy_costs}

                # Executing the API call
                logger.info(f"Querying Kubecost Allocation API for data between {start_h} and {end_h} "
                            f"in {granularity.lower()} granularity...")
                r = requests.get(f"{kubecost_api_endpoint}/model/allocation", params=params,
                                 timeout=(connection_timeout, read_timeout), verify=tls_verify)

                # Adding the hourly allocation data to the list that'll eventually contain a full 24-hour data
                if r.status_code == 200:
                    if list(filter(None, r.json()["data"])):
                        data.append(r.json()["data"][0])
                else:
                    try:
                        logger.error("Kubecost API returned non-200 status code, it returned status code \n"
                                     f'Error message: {r.json()["error"]}')
                        sys.exit(1)
                    except KeyError:
                        logger.error(f"Kubecost API returned non-200 status code, it returned status code "
                                     f"{r.status_code}\nError message: {r.json()}")
            if data:
                return data
            else:
                logger.error("API response appears to be empty.\n"
                             "This script collects data between 72 hours ago and 48 hours ago.\n"
                             "Make sure that you have data at least within this timeframe.")
                sys.exit()

        # If the step is "1d", or "1h" without pagination, the API call is executed once to collect the entire timeframe
        else:

            # Calculating the window and defining the API call requests parameters
            window = f'{start.strftime("%Y-%m-%dT%H:%M:%SZ")},{end.strftime("%Y-%m-%dT%H:%M:%SZ")}'
            if aggregate == "container":
                params = {"window": window, "accumulate": accumulate, "step": step, "idle": idle,
                          "splitIdle": split_idle, "idleByNode": idle_by_node, "shareTenancyCosts": share_tenancy_costs}
            else:
                params = {"window": window, "aggregate": aggregate, "accumulate": accumulate, "step": step,
                          "idle": idle, "splitIdle": split_idle, "idleByNode": idle_by_node,
                          "shareTenancyCosts": share_tenancy_costs}

            # Executing the API call
            logger.info(f"Querying Kubecost Allocation API for data between {start} and {end} "
                        f"in {granularity.lower()} granularity...")
            r = requests.get(f"{kubecost_api_endpoint}/model/allocation", params=params,
                             timeout=(connection_timeout, read_timeout), verify=tls_verify)

            if r.status_code == 200:
                if list(filter(None, r.json()["data"])):
                    return list(filter(None, r.json()["data"]))
                else:
                    logger.error("API response appears to be empty.\n"
                                 "This script collects data between 72 hours ago and 48 hours ago.\n"
                                 "Make sure that you have data at least within this timeframe.")
                    sys.exit()
            else:
                try:
                    logger.error("Kubecost API returned non-200 status code, it returned status code \n"
                                 f'Error message: {r.json()["error"]}')
                    sys.exit(1)
                except KeyError:
                    logger.error(f"Kubecost API returned non-200 status code, it returned status code {r.status_code}\n"
                                 f"Error message: {r.json()}")

    except requests.exceptions.ConnectTimeout:
        logger.error(f"Timed out waiting for TCP connection establishment in the given time ({connection_timeout}s). "
                     "Consider increasing the connection timeout value.")
        sys.exit(1)
    except requests.exceptions.JSONDecodeError as error:
        logger.error(f"Original error: '{error}'. "
                     "Check if you're using incorrect protocol in the URL "
                     "(for example, you're using 'http://..' when the API server is using HTTPS).")
        sys.exit()
    except requests.exceptions.SSLError as error:
        logger.error(error.args[0].reason)
        sys.exit(1)
    except OSError as error:
        logger.error(error)
        sys.exit(1)
    except requests.exceptions.ConnectionError as error:
        error_title = error.args[0].reason.args[0].split(": ")[1]
        error_reason = error.args[0].reason.args[0].split(": ")[-1].split("] ")[-1]
        logger.error(f"{error_title}: {error_reason}. Check that the service is listening, "
                     "and that you're using the correct port in your URL.")
        sys.exit(1)
    except requests.exceptions.ReadTimeout:
        logger.error("Timed out waiting for Kubecost Allocation API "
                     f"to send an HTTP response in the given time ({read_timeout}s). "
                     "Consider increasing the read timeout value.")
        sys.exit(1)


def kubecost_allocation_data_add_cluster_id_and_name(allocation_data, cluster_id):
    """Adds the cluster unique ID and name from the CLUSTER_ID input, to each allocation.
    The cluster ID is needed in case we'd like to identify the unique cluster ID in the dataset.
    The cluster name is needed because the Kubecost's representation of the cluster name might not be the real name.

    :param allocation_data: The allocation "data" list from Kubecost Allocation API response
    :param cluster_id: The cluster unique ID (for example, EKS cluster ARN)
    :return: Kubecost allocation data with the real EKS cluster name
    """

    for time_set in allocation_data:
        for allocation in time_set.values():
            if "properties" in allocation.keys():
                if "cluster" in allocation["properties"].keys():
                    allocation["properties"]["eksClusterName"] = cluster_id.split("/")[-1]
                    allocation["properties"]["clusterid"] = cluster_id

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


def kubecost_allocation_data_to_parquet(allocation_data,
                                        dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations,
                                        kubecost_labels_to_orig_labels,
                                        kubecost_annotations_to_orig_annotations):
    """Converting Kubecost Allocation data to Parquet.

    :param allocation_data: Kubecost's Allocation data after:
     1. Transforming to a nested list
     2. Updating timestamps
    :param dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations: Dictionary of DataFrame columns mapped to their NA/NaN value.
    This is including columns for K8s label keys, the way they're represented in Kubecost.
    :param kubecost_labels_to_orig_labels: A dict mapping the Kubecost K8s labels keys, to the original K8s labels keys
    :param kubecost_annotations_to_orig_annotations: A dict of Kubecost K8s annotations, to original K8s annotations
    :return:
    """

    # Converting Kubecost's Allocation data to Pandas DataFrame
    all_dfs = [pd.json_normalize(x) for x in allocation_data]
    df = pd.concat(all_dfs)

    # Renaming all node labels fields from Kubecost Allocation API to "properties." fields
    # This is to not confuse these fields with labels which aren't on the node
    df = df.rename(columns={"properties.labels.node_kubernetes_io_instance_type": "properties.node_instance_type",
                            "properties.labels.topology_kubernetes_io_region": "properties.region",
                            "properties.labels.topology_kubernetes_io_zone": "properties.node_availability_zone",
                            "properties.labels.kubernetes_io_arch": "properties.node_architecture",
                            "properties.labels.kubernetes_io_os": "properties.node_os"
                            })

    # Filling in an empty value for columns missing from the DataFrame (that were missing from the original dataset)
    # Converting NA/NaN to values to their respective empty value based on data type
    df = df.reindex(columns=dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations, fill_value="")
    df = df.fillna(value=dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations)

    # Adding common fields for EKS Node Group and Karpenter
    df["properties.node_capacity_type"] = df["properties.labels.eks_amazonaws_com_capacityType"] + df[
        "properties.labels.karpenter_sh_capacity_type"]
    df["properties.node_nodegroup"] = df["properties.labels.eks_amazonaws_com_nodegroup"] + df[
        "properties.labels.karpenter_sh_provisioner_name"]
    df["properties.node_nodegroup_image"] = df["properties.labels.eks_amazonaws_com_nodegroup_image"] + df[
        "properties.labels.karpenter_k8s_aws_instance_ami_id"]

    # Replacing value of "properties.provider" field based on the instance ID
    df["properties.provider"] = ["AWS" if x.startswith("i-") else "" for x in df["properties.providerID"]]

    # Static definitions of data types, to not have them mistakenly set as incorrect data type
    df["window.start"] = pd.to_datetime(df["window.start"], format="%Y-%m-%d %H:%M:%S.%f")
    df["window.end"] = pd.to_datetime(df["window.end"], format="%Y-%m-%d %H:%M:%S.%f")
    for column, na_value in dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations.items():
        if column not in ["window.start", "window.end"]:
            if type(na_value) == str:
                df[column] = df[column].astype("string")
            elif type(na_value) == int:
                df[column] = df[column].astype("float64")

    # Filtering the DataFrame to include only the desired columns
    df = df.loc[:, dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations.keys()]

    # Dropping EKS-specific and Karpenter-specific fields (after adding the common fields above)
    df = df.drop(
        columns=["properties.labels.eks_amazonaws_com_capacityType", "properties.labels.karpenter_sh_capacity_type",
                 "properties.labels.eks_amazonaws_com_nodegroup", "properties.labels.karpenter_sh_provisioner_name",
                 "properties.labels.eks_amazonaws_com_nodegroup_image",
                 "properties.labels.karpenter_k8s_aws_instance_ami_id"])

    # Renaming columns of the Kubecost representation of K8s labels to the original K8s labels
    if kubecost_labels_to_orig_labels:
        kubecost_labels_to_orig_labels_only_renamed = {k: v for k, v in kubecost_labels_to_orig_labels.items() if
                                                       re.search(r"[./-]", v.strip("properties.labels."))}
        if kubecost_labels_to_orig_labels_only_renamed:
            df = df.rename(columns=kubecost_labels_to_orig_labels_only_renamed)

    # Renaming columns of the Kubecost representation of K8s annotations to the original K8s annotations
    if kubecost_annotations_to_orig_annotations:
        kubecost_annotations_to_orig_annotations_only_renamed = {k: v for k, v in
                                                                 kubecost_annotations_to_orig_annotations.items() if
                                                                 re.search(r"[./-]",
                                                                           v.strip("properties.annotations."))}
        if kubecost_annotations_to_orig_annotations_only_renamed:
            df = df.rename(columns=kubecost_annotations_to_orig_annotations_only_renamed)

    # Transforming the DataFrame to a Parquet and creating the Parquet file locally
    df.to_parquet("/tmp/output.snappy.parquet", engine="pyarrow")


def upload_kubecost_allocation_parquet_to_s3(s3_bucket_name, cluster_id, date, month, year, assume_role_response):
    """Compresses and uploads the Kubecost Allocation Parquet to an S3 bucket.

    :param s3_bucket_name: The S3 bucket name to use
    :param cluster_id: The cluster ID to use for the S3 bucket prefix and Parquet file name
    :param date: The date to use in the Parquet file name
    :param month: The month to use as part of the S3 bucket prefix
    :param year: The year to use as part of the S3 bucket prefix
    :param assume_role_response: The Assume Role API call response
    :return:
    """

    # Removing the "REQUESTS_CA_BUNDLE" environment variable, if exists for the Kubecost API calls
    # This is so that Boto3 will use the default CA bundle to make the TLS connection to AWS API
    try:
        del os.environ["REQUESTS_CA_BUNDLE"]
    except KeyError:
        pass

    cluster_name = cluster_id.split("/")[-1]
    cluster_account_id = cluster_id.split(":")[4]
    cluster_region_code = cluster_id.split(":")[3]

    # Compressing and uploading the Parquet file to the S3 bucket
    s3_file_name = f"{date}_{cluster_name}"
    os.rename("/tmp/output.snappy.parquet", f"/tmp/{s3_file_name}.snappy.parquet")
    try:
        # Client definition in case the EKS cluster and AWS Secrets Manager are in different AWS accounts.
        # This means cross account authentication will be done, so the client contains the parent IAM role credentials
        if assume_role_response:
            s3 = boto3.resource("s3", aws_access_key_id=assume_role_response["Credentials"]["AccessKeyId"],
                                aws_secret_access_key=assume_role_response["Credentials"]["SecretAccessKey"],
                                aws_session_token=assume_role_response["Credentials"]["SessionToken"])

        # Client definition in case the EKS cluster and AWS Secrets Manager are in the same AWS account.
        # This means cross account authentication isn't necessary, so IRSA credentials will be used
        else:
            s3 = boto3.resource("s3")
        s3_bucket_prefix = f"account_id={cluster_account_id}/region={cluster_region_code}/year={year}/month={month}"

        logger.info(f"Uploading file '{s3_file_name}.snappy.parquet' to S3 Bucket '{s3_bucket_name}'...")
        s3.Bucket(s3_bucket_name).upload_file(f"/tmp/{s3_file_name}.snappy.parquet",
                                              f"{s3_bucket_prefix}/{s3_file_name}.snappy.parquet")
    except boto3.exceptions.S3UploadFailedError as error:
        logger.error(f"Unable to upload file {s3_file_name}.snappy.parquet to S3 Bucket '{s3_bucket_name}': {error}")
        sys.exit(1)
    except botocore.exceptions.ClientError as error:
        logger.error(error)
        sys.exit(1)


def main():

    ################
    # Preparations #
    ################

    # The below set of functions are used to prepare things needed to execute other logic, as follows:
    # 1. Define the DataFrame columns
    # 2. Assume IAM Role to be used in all other AWS API calls
    # 3. Optionally, retrieve Kubecost root CA certificate from AWS Secrets Manager

    # Creating a mapping of Kubecost K8s labels and annotations to original K8s labels and annotations
    kubecost_labels_to_orig_labels = create_kubecost_labels_to_k8s_labels_mapping(LABELS)
    kubecost_annotations_to_orig_annotations = create_kubecost_annotations_to_k8s_annotations_mapping(ANNOTATIONS)

    # Defining a mapping of the DataFrame columns to their NA/NaN value
    dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations = define_dataframe_columns(
        kubecost_labels_to_orig_labels, kubecost_annotations_to_orig_annotations)

    # In case the EKS cluster and target services (AWS Secret Manager and S3) are in different account:
    # Assume IAM Role once, to be used in all other AWS API calls
    # Content of "assume_role_response" will be the sts:AssumeRole API response
    # Otherwise:
    # Sets "assume_role_response" to "None"
    # Functions executing AWS API calls conditionally set their credentials as follows:
    # If "assume_role_response" has content, using the assumed role credentials
    # If "assume_role_response" is "None", they won't pass credentials, but will use the IRSA credentials
    if IRSA_PARENT_IAM_ROLE_ARN:
        assume_role_response = iam_assume_role(IRSA_PARENT_IAM_ROLE_ARN, "kubecost-s3-exporter")
    else:
        assume_role_response = None

    # If the user gave a secret name as an input to the "KUBECOST_CA_CERTIFICATE_SECRET_NAME" environment variable
    # 1. The secret with the given name will be retrieved from AWS Secrets Manager
    # 2. A file will be created from the content of the CA certificate
    # 3. The "REQUESTS_CA_BUNDLE" will be set with the file path
    if KUBECOST_CA_CERTIFICATE_SECRET_NAME:
        kubecost_ca_cert = secrets_manager_get_secret_value(KUBECOST_CA_CERTIFICATE_SECRET_NAME,
                                                            KUBECOST_CA_CERTIFICATE_SECRET_REGION, assume_role_response)
        create_ca_cert_file(kubecost_ca_cert)

    ##################
    # Backfill logic #
    ##################

    # The below set of functions is used to calculate which dates should be collected from Kubecost.
    # This is based on a backfill period in days that is given as an input (default is 15 days).
    # The logic is as follows:

    # Based on the given backfill period, the following is done:
    # 1. The window for the Kubecost API call is defined, based on the backfill period.
    # The start date is the first day of the backfill period, and end date is 2 days ago (from today).
    # 2. Executing Kubecost Allocation API call for the above window.
    # The API call is executed with the highest possible aggregation (cluster), daily granularity, and "1d" resolution
    # This is to improve performance, as cost data isn't needed from this API.
    # The only purpose of executing this API call is to later extract the dates of each timeset (each day).
    # 3. Extracting the dates and the window for each timeset in the API response.
    # This is how the dates with available data in the backfill period are identified.
    # This list of dates is used as a baseline to later compare which of these dates is missing (if at all) from S3
    # 4. Extracting the dates available in S3 for the backfill period, for this cluster
    # 5. Find the missing dates in S3, by comparing the dates available in Kubecost with the dates available in S3.
    # Those dates will be used as input to the data collection logic.

    logger.info("### Backfill Dates Calculation Logic Start ###")

    # Define the Kubecost window, execute Kubecost API call and extract the dates and window for each timeset
    kubecost_backfill_start_date_midnight, kubecost_backfill_end_date_midnight = kubecost_backfill_period_window_calc(
        BACKFILL_PERIOD_DAYS)
    kubecost_backfill_period_allocation_data = execute_kubecost_allocation_api(TLS_VERIFY, KUBECOST_API_ENDPOINT,
                                                                               kubecost_backfill_start_date_midnight,
                                                                               kubecost_backfill_end_date_midnight,
                                                                               "daily", "cluster", CONNECTION_TIMEOUT,
                                                                               KUBECOST_ALLOCATION_API_READ_TIMEOUT,
                                                                               "No", True, True, True, True, False)
    kubecost_backfill_period_available_dates = get_kubecost_backfill_period_available_dates(
        kubecost_backfill_period_allocation_data)

    # Get available dates in S3
    s3_backfill_period_available_dates = get_s3_backfill_period_available_dates(S3_BUCKET_NAME, CLUSTER_ID,
                                                                                BACKFILL_PERIOD_DAYS,
                                                                                assume_role_response)

    # Find missing dates in S3
    kubecost_dates_missing_from_s3 = calc_kubecost_dates_missing_from_s3(kubecost_backfill_period_available_dates,
                                                                         s3_backfill_period_available_dates)

    logger.info("### Backfill Dates Calculation Logic End ###")

    #########################
    # Data Collection Logic #
    #########################

    # The below set of functions is used collect the data from Kubecost, convert it to Parquet and upload it to S3.
    # The collection windows are based on the result of the backfill logic above.
    # The logic is as follows, for each date identified as missing in S3 (if any. If none - data collection isn't done):
    # 1. Executing the Kubecost Allocation API call
    # 2. Executing the Kubecost Assets API call
    # 3. Performing different changes on the data:
    # 3.1 Adding the real cluster ID and name to each allocation properties
    # 3.2 Consolidating the Allocation data and the Assets data to a single JSON
    # 3.3 Updating the timestamps to java.sql.Timestamp format
    # 4. Converting the JSON to DataFrame, then to Snappy-compressed Parquet.
    # As part of this transformation, the following is also done:
    # 4.1 All node labels fields are converted to "properties." labels to not confuse them with workloads labels
    # 4.2 Columns that are completely missing from the DataFrame, are added with an empty value.
    # 4.3 Any NA/NaN value is converted to a defined value based on the datatype
    # 4.3 EKS-specific Node Group fields and Karpenter-specific fields are dropped and replaced with common fields
    # 4.4 Provider field is added based on instance ID
    # 4.5 Static data types are set for each column
    # 4.6 Label keys that were renamed by Kubecost are renamed back to their original label key
    # 4.7 The DataFrame is filtered to include only the required column
    # 4.8 The Dataframe is converted to Snappy-compressed Parquet
    # 5. Uploading the Snappy-compressed Parquet file to S3

    if kubecost_dates_missing_from_s3:

        logger.info("### Data Collection Logic Start ###")
        logger.info(f"Data will be collected from Kubecost for dates {', '.join(kubecost_dates_missing_from_s3)}")

        for date, window in kubecost_dates_missing_from_s3.items():
            start = datetime.datetime.strptime(window["start"], "%Y-%m-%dT%H:%M:%SZ")
            end = datetime.datetime.strptime(window["end"], "%Y-%m-%dT%H:%M:%SZ")
            year = date.split("-")[0]
            month = date.split("-")[1]

            # Executing Kubecost Allocation API call
            kubecost_allocation_data = execute_kubecost_allocation_api(TLS_VERIFY, KUBECOST_API_ENDPOINT, start, end,
                                                                       "daily", AGGREGATION, CONNECTION_TIMEOUT,
                                                                       KUBECOST_ALLOCATION_API_READ_TIMEOUT,
                                                                       KUBECOST_ALLOCATION_API_PAGINATE, True, True,
                                                                       True, True, False)

            # Adding the real cluster ID and name from the cluster ID input
            kubecost_allocation_data_with_eks_cluster_name = kubecost_allocation_data_add_cluster_id_and_name(
                kubecost_allocation_data, CLUSTER_ID)

            # Transforming Kubecost's Allocation API data to a list of lists, and updating timestamps
            kubecost_updated_allocation_data = kubecost_allocation_data_timestamp_update(
                kubecost_allocation_data_with_eks_cluster_name)

            # Transforming Kubecost's updated allocation data to a Snappy-compressed Parquet, and uploading it to S3
            kubecost_allocation_data_to_parquet(kubecost_updated_allocation_data,
                                                dataframe_columns_to_na_value_mapping_with_kubecost_labels_annotations,
                                                kubecost_labels_to_orig_labels,
                                                kubecost_annotations_to_orig_annotations)
            upload_kubecost_allocation_parquet_to_s3(S3_BUCKET_NAME, CLUSTER_ID, date, month,
                                                     year, assume_role_response)

        logger.info("### Data Collection Logic End ###")


if __name__ == "__main__":
    main()
