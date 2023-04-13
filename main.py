# Copyright 2022 Amazon.com and its affiliates; all rights reserved.
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

# Mandatory environment variables,  to make sure they're not empty
try:
    S3_BUCKET_NAME = os.environ["S3_BUCKET_NAME"]
except KeyError:
    logger.error("The 'S3_BUCKET_NAME' input is a required, but it's missing")
    sys.exit(1)
try:
    CLUSTER_ID = os.environ["CLUSTER_ID"]
except KeyError:
    logger.error("The 'CLUSTER_ID' input is a required, but it's missing")
    sys.exit(1)
try:
    IRSA_PARENT_IAM_ROLE_ARN = os.environ["IRSA_PARENT_IAM_ROLE_ARN"]
except KeyError:
    logger.error("The 'IRSA_PARENT_IAM_ROLE_ARN' input is a required, but it's missing")
    sys.exit(1)

# Optional environment variables, and input validations
KUBECOST_API_ENDPOINT = os.environ.get("KUBECOST_API_ENDPOINT", "http://kubecost-cost-analyzer.kubecost:9090")

GRANULARITY = os.environ.get("GRANULARITY", "hourly").lower()
if GRANULARITY not in ["hourly", "daily"]:
    logger.error("Granularity must be one of 'hourly' or 'daily' (case-insensitive)")
    sys.exit(1)

AGGREGATION = os.environ.get("AGGREGATION", "container")
if AGGREGATION not in ["container", "pod", "namespace", "controller", "controllerKind", "node", "cluster"]:
    logger.error("Aggregation must be one of 'container', 'pod', 'namespace', 'controller', 'controllerKind', 'node', or 'cluster'")
    sys.exit(1)

KUBECOST_ALLOCATION_API_PAGINATE = os.environ.get("KUBECOST_ALLOCATION_API_PAGINATE", "No").lower()
if KUBECOST_ALLOCATION_API_PAGINATE not in ["yes", "no", "y", "n"]:
    logger.error("The 'KUBECOST_ALLOCATION_API_PAGINATE' input must be one of 'Yes', 'No', 'Y' or 'N' (case-insensitive)")
    sys.exit(1)

KUBECOST_ALLOCATION_API_RESOLUTION = os.environ.get("KUBECOST_ALLOCATION_API_RESOLUTION", "1m")
if not re.match(r"^[1-9][0-9]?m.*$", KUBECOST_ALLOCATION_API_RESOLUTION):
    logger.error("The 'KUBECOST_ALLOCATION_API_RESOLUTION' input must be in format of 'Nm', where N >= 1.\n"
                 "For example, 1m, 2m, 5m, 10m.")
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

try:
    KUBECOST_ASSETS_API_READ_TIMEOUT = float(os.environ.get("KUBECOST_ASSETS_API_READ_TIMEOUT", 30))
    if KUBECOST_ASSETS_API_READ_TIMEOUT <= 0:
        logger.error("The read timeout must be a non-zero positive float")
        sys.exit(1)
except ValueError:
    logger.error("The read timeout must be a float")
    sys.exit(1)

TLS_VERIFY = os.environ.get("TLS_VERIFY", "Yes").lower()
if TLS_VERIFY in ["yes", "y"]:
    TLS_VERIFY = True
elif TLS_VERIFY in ["no", "n"]:
    TLS_VERIFY = False
else:
    logger.error("The 'TLS_VERIFY' input must be one of 'Yes', 'No', 'Y' or 'N' (case-insensitive)")
    sys.exit(1)

REQUESTS_CA_BUNDLE = os.environ.get("REQUESTS_CA_BUNDLE")
LABELS = os.environ.get("LABELS")


def cluster_id_input_validation(cluster_id, input_name):
    """This function is used to validate the cluster ID input.
    Currently, it supports validating only EKS cluster ARN.

    :param cluster_id: The cluster ID
    :param input_name: The input name
    :return:
    """

    # The below validation validates an EKS cluster ARN input.
    # It'll return the specified error if the input fails the validation.
    # Here are a few examples of an EKS cluster ARN input that'll fail validation:
    # The EKS cluster ARN input is empty ("")
    # The EKS cluster ARN input has some unstructured string (e.g. "test")
    # The EKS cluster ARN input has less than 6 ARN fields ("arn:aws:eks")
    # The EKS cluster ARN input has 6 ARN fields, but is missing the "/" before the resource ID. Example:
    # "arn:aws:eks:us-east-1:111111111111:cluster"
    # The EKS cluster name part of the ARN doesn't match the EKS cluster name rules
    # The EKS cluster ARN input has missing ARN fields or has incorrect value in some ARN fields. A few examples:
    # arn:aws:eks:us-east-1:111111111111:cluster/
    # arn:aws:eks:us-east-1:123:cluster/cluster1
    # arn:aws:eks:us-east-1::cluster/cluster1
    # arn:aws:eks:aaa:111111111111:cluster/cluster1
    # arn:aws:eks::111111111111:cluster/cluster1
    # arn:aws:s3:us-east-1:111111111111:cluster/cluster1
    # arn:aaa:eks:us-east-1:111111111111:cluster/cluster1

    regex = r"^arn:(?:aws|aws-cn|aws-us-gov):eks:(?:us(?:-gov)?|ap|ca|cn|eu|sa)-(?:central|(?:north|south)?(?:east|west)?)-\d:\d{12}:cluster/[a-zA-Z0-9][a-zA-Z0-9-_]{1,99}$"
    if not re.match(regex, cluster_id):
        logger.error(f"The '{input_name}' input contains an invalid EKS cluster ARN: {cluster_id}")
        sys.exit(1)


def iam_role_arn_input_validation(iam_role_arn, input_name):
    """This function is used to validate an IAN Role ARN input.

    :param iam_role_arn: The IAM Role ARN
    :param input_name: The input name
    :return:
    """

    # The below validation validates an IAM Role input.
    # It'll return the specified error if the input fails the validation.
    # Here are a few examples of an IAM Role input that'll fail validation:
    # The IAM Role input is empty ("")
    # The IAM Role input has some unstructured string (e.g. "test")
    # The IAM Role input has less than 6 ARN fields ("arn:aws:eks")
    # The IAM Role input has 6 ARN fields, but is missing the "/" before the resource ID. Example:
    # "arn:aws:iam::111111111111:role"
    # The IAM Role name part of the ARN doesn't match the IAM Role name rules
    # The IAM Role input has missing ARN fields or has incorrect value in some ARN fields. A few examples:
    # arn:aws:iam::111111111111:role/
    # arn:aws:iam::123:role/role1
    # arn:aws:iam:::role/role1
    # arn:aws:iam:us-east-1:111111111111:role/role1
    # arn:aws:s3::111111111111:role/role1
    # arn:aaa:iam::111111111111:role/role1

    regex = r"^arn:(?:aws|aws-cn|aws-us-gov):iam::\d{12}:role/[a-zA-Z0-9+=,.@-_]{1,64}$"
    if not re.match(regex, iam_role_arn):
        logger.error(f"The '{input_name}' input contains an invalid ARN: {iam_role_arn}")
        sys.exit(1)


def kubecost_api_endpoint_input_validation(kubecost_api_endpoint):
    """This function is used to validate the Kubecost API endpoint input (KUBECOST_API_ENDPOINT).

    :param kubecost_api_endpoint: The Kubecost API endpoint input
    :return:
    """

    regex = r"^https?://.+$"
    if not re.match(regex, kubecost_api_endpoint):
        logger.error("The Kubecost API endpoint is invalid. It must be in the format of 'http://<name_or_ip>:[port]' or 'https://<name_or_ip>:[port]'")
        sys.exit(1)


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
        "properties.provider",
        "properties.region",
        "properties.cluster",
        "properties.clusterid",
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


def execute_kubecost_allocation_api(tls_verify, kubecost_api_endpoint, start, end, granularity, aggregate,
                                    connection_timeout, read_timeout, paginate, resolution, accumulate=False):
    """Executes Kubecost Allocation On-Demand API.

    :param tls_verify: Dictates whether TLS certificate verification is done for HTTPS connections
    :param kubecost_api_endpoint: The Kubecost API endpoint, in format of "http://<ip_or_name>:<port>"
    :param start: The start time for calculating Kubecost Allocation API window
    :param end: The end time for calculating Kubecost Allocation API window
    :param granularity: The user input time granularity, to use for calculating the step (daily or hourly)
    :param aggregate: The K8s object used for aggregation, as per Kubecost Allocation API On-demand query documentation
    :param connection_timeout: The timeout (in seconds) to wait for TCP connection establishment
    :param read_timeout: The timeout (in seconds) to wait for the server to send an HTTP response
    :param paginate: Dictates whether to paginate using 1-hour time ranges (relevant for "1h" step)
    :param resolution: The Kubecost Allocation On-demand API resolution, to control accuracy vs performance
    :param accumulate: Dictates whether to return data for the entire window, or divide to time sets
    :return: The Kubecost Allocation API On-demand query "data" list from the HTTP response
    """

    # Setting the step
    step = "1h" if granularity == "hourly" else "1d"

    # Executing Kubecost Allocation API call (On-demand query)
    try:

        # If the step is defined as "1h", the API call is for each hour in the 24-hour timeframe
        # This is to prevent OOM in the Kubecost/Prometheus containers, and to avoid using high read-timeout value
        if step == "1h" and paginate in ["yes", "y"]:

            data = []
            for n in range(1, 25):

                start_h = start + datetime.timedelta(hours=n - 1)
                end_h = start + datetime.timedelta(hours=n)

                # Calculating the window and defining the API call requests parameters
                window = f'{start_h.strftime("%Y-%m-%dT%H:%M:%SZ")},{end_h.strftime("%Y-%m-%dT%H:%M:%SZ")}'
                if aggregate == "container":
                    params = {"window": window, "accumulate": accumulate, "step": step, "resolution": resolution}
                else:
                    params = {"window": window, "aggregate": aggregate, "accumulate": accumulate, "step": step,
                              "resolution": resolution}

                # Executing the API call
                logger.info(f"Querying Kubecost Allocation On-demand Query API for data between {start_h} and {end_h} "
                            f"in {granularity.lower()} granularity...")
                r = requests.get(f"{kubecost_api_endpoint}/model/allocation/compute", params=params,
                                 timeout=(connection_timeout, read_timeout), verify=tls_verify)

                # Adding the hourly allocation data to the list that'll eventually contain a full 24-hour data
                if list(filter(None, r.json()["data"])):
                    data.append(r.json()["data"][0])

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
                params = {"window": window, "accumulate": accumulate, "step": step, "resolution": resolution}
            else:
                params = {"window": window, "aggregate": aggregate, "accumulate": accumulate, "step": step,
                          "resolution": resolution}

            # Executing the API call
            logger.info(f"Querying Kubecost Allocation On-demand Query API for data between {start} and {end} "
                        f"in {granularity.lower()} granularity...")
            r = requests.get(f"{kubecost_api_endpoint}/model/allocation/compute", params=params,
                             timeout=(connection_timeout, read_timeout), verify=tls_verify)

            if list(filter(None, r.json()["data"])):
                return r.json()["data"]
            else:
                logger.error("API response appears to be empty.\n"
                             "This script collects data between 72 hours ago and 48 hours ago.\n"
                             "Make sure that you have data at least within this timeframe.")
                sys.exit()

    except requests.exceptions.ConnectTimeout:
        logger.error(f"Timed out waiting for TCP connection establishment in the given time ({connection_timeout}s). "
                     "Consider increasing the connection timeout value.")
        sys.exit(1)
    except requests.exceptions.JSONDecodeError as error:
        logger.error(f"Original error: '{error}'. "
                     "Check if you're using incorrect protocol in the URL "
                     "(for example, you're using 'http://...' when the API server is using HTTPS).")
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
        logger.error("Timed out waiting for Kubecost Allocation On-Demand API "
                     f"to send an HTTP response in the given time ({read_timeout}s). "
                     "Consider increasing the read timeout value.")
        sys.exit(1)


def execute_kubecost_assets_api(tls_verify, kubecost_api_endpoint, start, end, connection_timeout, read_timeout,
                                accumulate=False):
    """Executes Kubecost Assets API.

    :param tls_verify: Dictates whether TLS certificate verification is done for HTTPS connections
    :param kubecost_api_endpoint: The Kubecost API endpoint, in format of "http://<ip_or_name>:<port>"
    :param start: The start time for calculating Kubecost Allocation API window
    :param end: The end time for calculating Kubecost Allocation API window
    :param connection_timeout: The timeout (in seconds) to wait for TCP connection establishment
    :param read_timeout: The timeout (in seconds) to wait for the server to send an HTTP response
    :param accumulate: Dictates whether to return data for the entire window, or divide to time sets
    :return: The Kubecost Assets API On-demand query "data" list from the HTTP response
    """

    # Calculating the window
    window = f'{start.strftime("%Y-%m-%dT%H:%M:%SZ")},{end.strftime("%Y-%m-%dT%H:%M:%SZ")}'

    # Executing Kubecost Assets API call
    try:
        logger.info(f"Querying Kubecost Assets API for data between {start} and {end}")
        params = {"window": window, "accumulate": accumulate, "filterCategories": "Compute", "filterTypes": "Node"}
        r = requests.get(f"{kubecost_api_endpoint}/model/assets", params=params,
                         timeout=(connection_timeout, read_timeout), verify=tls_verify)
        if list(filter(None, r.json()["data"])):
            return r.json()["data"]
        else:
            logger.error("API response appears to be empty.\n"
                         "This script collects data between 72 hours ago and 48 hours ago.\n"
                         "Make sure that you have data at least within this timeframe.")
            sys.exit()

    except requests.exceptions.ConnectTimeout:
        logger.error(f"Timed out waiting for TCP connection establishment in the given time ({connection_timeout}s). "
                     "Consider increasing the connection timeout value.")
        sys.exit(1)
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
        logger.error(f"Timed out waiting for Kubecost Assets API "
                     f"to send an HTTP response in the given time ({read_timeout}s). "
                     f"Consider increasing the read timeout value.")
        sys.exit(1)


def kubecost_allocation_data_add_cluster_id_and_name_from_input(allocation_data, cluster_id):
    """Adds the cluster unique ID and name from the CLUSTER_ID input, to each allocation.
    The cluster ID is needed in case we'd like to identify the unique cluster ID in the dataset.
    The cluster name is needed because the Kubecost's representation of the cluster name might not be the real name.

    :param allocation_data: the allocation "data" list from Kubecost Allocation API On-demand query HTTP response
    :param cluster_id: the cluster unique ID (for example, EKS cluster ARN)
    :return: Kubecost allocation data with the real EKS cluster name
    """

    for time_set in allocation_data:
        for allocation in time_set.values():
            if "properties" in allocation.keys():
                if "cluster" in allocation["properties"].keys():
                    allocation["properties"]["eksClusterName"] = cluster_id.split("/")[-1]
                    allocation["properties"]["clusterid"] = cluster_id

    return allocation_data


def kubecost_allocation_data_add_assets_data(allocation_data, assets_data):
    """Adds assets data from the Kubecost Assets API to the Kubecost allocation data.

    :param allocation_data: the allocation "data" list from Kubecost Allocation API
    :param assets_data: the asset "data" list from the Kubecost Assets API query HTTP response
    :return: Kubecost allocation data with matching asset data
    """

    all_assets_ids = assets_data[0].keys()

    for time_set in allocation_data:
        for allocation in time_set.values():
            if "properties" in allocation.keys():
                if "providerID" in allocation["properties"].keys() \
                        and "cluster" in allocation["properties"].keys() \
                        and "node" in allocation["properties"].keys():

                    # Identify the asset ID that matches the allocation's instance ID
                    asset_id = [asset_id_key for asset_id_key in all_assets_ids if
                                asset_id_key.split("/")[-2] == allocation["properties"]["providerID"]][0]

                    # Updating matching asset data from the Assets API, on the allocation properties
                    # If a certain asset data isn't found, the field is added to the allocation data as an empty string
                    # This is to keep the dataset with all required fields
                    try:
                        allocation["properties"]["provider"] = assets_data[0][asset_id]["properties"]["provider"]
                    except KeyError:
                        allocation["properties"]["provider"] = ""
                    try:
                        allocation["properties"]["region"] = assets_data[0][asset_id]["labels"][
                            "label_topology_kubernetes_io_region"]
                    except KeyError:
                        allocation["properties"]["region"] = ""
                    try:
                        allocation["properties"]["node_instance_type"] = assets_data[0][asset_id]["nodeType"]
                    except KeyError:
                        allocation["properties"]["node_instance_type"] = ""
                    try:
                        allocation["properties"]["node_availability_zone"] = assets_data[0][asset_id]["labels"][
                            "label_topology_kubernetes_io_zone"]
                    except KeyError:
                        allocation["properties"]["node_availability_zone"] = ""
                    try:
                        allocation["properties"]["node_capacity_type"] = assets_data[0][asset_id]["labels"][
                            "label_eks_amazonaws_com_capacityType"]
                    except KeyError:
                        allocation["properties"]["node_capacity_type"] = ""
                    try:
                        allocation["properties"]["node_architecture"] = assets_data[0][asset_id]["labels"][
                            "label_kubernetes_io_arch"]
                    except KeyError:
                        allocation["properties"]["node_architecture"] = ""
                    try:
                        allocation["properties"]["node_os"] = assets_data[0][asset_id]["labels"][
                            "label_kubernetes_io_os"]
                    except KeyError:
                        allocation["properties"]["node_os"] = ""
                    try:
                        allocation["properties"]["node_nodegroup"] = assets_data[0][asset_id]["labels"][
                            "label_eks_amazonaws_com_nodegroup"]
                    except KeyError:
                        allocation["properties"]["node_nodegroup"] = ""
                    try:
                        allocation["properties"]["node_nodegroup_image"] = assets_data[0][asset_id]["labels"][
                            "label_eks_amazonaws_com_nodegroup_image"]
                    except KeyError:
                        allocation["properties"]["node_nodegroup_image"] = ""

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


def kubecost_csv_allocation_data_to_parquet(csv_file_name, labels):
    """Converting Kubecost Allocation data from CSV to Parquet.

    :param csv_file_name: the name of the CSV file
    :return:
    """

    df = pd.read_csv(csv_file_name, encoding='utf8', sep=",", quotechar="'", escapechar="\\")

    # Static definitions of data types, to not have them mistakenly set as incorrect data type
    df["name"] = df["name"].astype("object")
    df["window.start"] = pd.to_datetime(df["window.start"], format="%Y-%m-%d %H:%M:%S.%f")
    df["window.end"] = pd.to_datetime(df["window.end"], format="%Y-%m-%d %H:%M:%S.%f")
    df["minutes"] = df["minutes"].astype("float64")
    df["cpuCores"] = df["cpuCores"].astype("float64")
    df["cpuCoreRequestAverage"] = df["cpuCoreRequestAverage"].astype("float64")
    df["cpuCoreUsageAverage"] = df["cpuCoreUsageAverage"].astype("float64")
    df["cpuCoreHours"] = df["cpuCoreHours"].astype("float64")
    df["cpuCost"] = df["cpuCost"].astype("float64")
    df["cpuCostAdjustment"] = df["cpuCostAdjustment"].astype("float64")
    df["cpuEfficiency"] = df["cpuEfficiency"].astype("float64")
    df["gpuCount"] = df["gpuCount"].astype("float64")
    df["gpuHours"] = df["gpuHours"].astype("float64")
    df["gpuCost"] = df["gpuCost"].astype("float64")
    df["gpuCostAdjustment"] = df["gpuCostAdjustment"].astype("float64")
    df["networkTransferBytes"] = df["networkTransferBytes"].astype("float64")
    df["networkReceiveBytes"] = df["networkReceiveBytes"].astype("float64")
    df["networkCost"] = df["networkCost"].astype("float64")
    df["networkCostAdjustment"] = df["networkCostAdjustment"].astype("float64")
    df["loadBalancerCost"] = df["loadBalancerCost"].astype("float64")
    df["loadBalancerCostAdjustment"] = df["loadBalancerCostAdjustment"].astype("float64")
    df["pvBytes"] = df["pvBytes"].astype("float64")
    df["pvByteHours"] = df["pvByteHours"].astype("float64")
    df["pvCost"] = df["pvCost"].astype("float64")
    df["pvCostAdjustment"] = df["pvCostAdjustment"].astype("float64")
    df["ramBytes"] = df["ramBytes"].astype("float64")
    df["ramByteRequestAverage"] = df["ramByteRequestAverage"].astype("float64")
    df["ramByteUsageAverage"] = df["ramByteUsageAverage"].astype("float64")
    df["ramByteHours"] = df["ramByteHours"].astype("float64")
    df["ramCost"] = df["ramCost"].astype("float64")
    df["ramCostAdjustment"] = df["ramCostAdjustment"].astype("float64")
    df["ramEfficiency"] = df["ramEfficiency"].astype("float64")
    df["sharedCost"] = df["sharedCost"].astype("float64")
    df["externalCost"] = df["externalCost"].astype("float64")
    df["totalCost"] = df["totalCost"].astype("float64")
    df["totalEfficiency"] = df["totalEfficiency"].astype("float64")
    df["properties.provider"] = df["properties.provider"].astype("object")
    df["properties.region"] = df["properties.region"].astype("object")
    df["properties.cluster"] = df["properties.cluster"].astype("object")
    df["properties.clusterid"] = df["properties.clusterid"].astype("object")
    df["properties.eksClusterName"] = df["properties.eksClusterName"].astype("object")
    df["properties.container"] = df["properties.container"].astype("object")
    df["properties.namespace"] = df["properties.namespace"].astype("object")
    df["properties.node"] = df["properties.node"].astype("object")
    df["properties.node_instance_type"] = df["properties.node_instance_type"].astype("object")
    df["properties.node_availability_zone"] = df["properties.node_availability_zone"].astype("object")
    df["properties.node_capacity_type"] = df["properties.node_capacity_type"].astype("object")
    df["properties.node_architecture"] = df["properties.node_architecture"].astype("object")
    df["properties.node_os"] = df["properties.node_os"].astype("object")
    df["properties.node_nodegroup"] = df["properties.node_nodegroup"].astype("object")
    df["properties.node_nodegroup_image"] = df["properties.node_nodegroup_image"].astype("object")
    df["properties.controller"] = df["properties.controller"].astype("object")
    df["properties.controllerKind"] = df["properties.controllerKind"].astype("object")
    df["properties.providerID"] = df["properties.providerID"].astype("object")
    if labels:
        labels_columns = ["properties.labels." + x.strip() for x in labels.split(",")]
        for labels_column in labels_columns:
            df[labels_column] = df[labels_column].astype("object")

    df.to_parquet("output.snappy.parquet", engine="pyarrow")


def upload_kubecost_allocation_parquet_to_s3(s3_bucket_name, cluster_id, date, month, year):
    """Compresses and uploads the Kubecost Allocation Parquet to an S3 bucket.

    :param s3_bucket_name: the S3 bucket name to use
    :param cluster_id: the cluster ID to use for the S3 bucket prefix and Parquet file name
    :param date: the date to use in the Parquet file name
    :param month: the month to use as part of the S3 bucket prefix
    :param year: the year to use as part of the S3 bucket prefix
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
    os.rename("output.snappy.parquet", f"{s3_file_name}.snappy.parquet")
    try:
        sts = boto3.client("sts")
        sts_response = sts.assume_role(RoleArn=IRSA_PARENT_IAM_ROLE_ARN,
                                       RoleSessionName="kubecost-s3-exporter")
        s3 = boto3.resource("s3", aws_access_key_id=sts_response["Credentials"]["AccessKeyId"],
                            aws_secret_access_key=sts_response["Credentials"]["SecretAccessKey"],
                            aws_session_token=sts_response["Credentials"]["SessionToken"])
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

    # Input validations for the cluster ID, IRSA parent IAM Role ARN, and Kubecost API endpoint
    cluster_id_input_validation(CLUSTER_ID, "CLUSTER_ID")
    iam_role_arn_input_validation(IRSA_PARENT_IAM_ROLE_ARN, "IRSA_PARENT_IAM_ROLE_ARN")
    kubecost_api_endpoint_input_validation(KUBECOST_API_ENDPOINT)

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
    kubecost_allocation_data = execute_kubecost_allocation_api(TLS_VERIFY, KUBECOST_API_ENDPOINT,
                                                               three_days_ago_midnight,
                                                               three_days_ago_midnight_plus_one_day, GRANULARITY,
                                                               AGGREGATION, CONNECTION_TIMEOUT,
                                                               KUBECOST_ALLOCATION_API_READ_TIMEOUT,
                                                               KUBECOST_ALLOCATION_API_PAGINATE,
                                                               KUBECOST_ALLOCATION_API_RESOLUTION)

    kubecost_assets_data = execute_kubecost_assets_api(TLS_VERIFY, KUBECOST_API_ENDPOINT, three_days_ago_midnight,
                                                       three_days_ago_midnight_plus_one_day, CONNECTION_TIMEOUT,
                                                       KUBECOST_ASSETS_API_READ_TIMEOUT)

    # Adding the real cluster ID and name from the cluster ID input
    kubecost_allocation_data_with_eks_cluster_name = kubecost_allocation_data_add_cluster_id_and_name_from_input(
        kubecost_allocation_data, CLUSTER_ID)

    # Adding assets data from the Kubecost Assets API
    kubecost_allocation_data_with_assets_data = kubecost_allocation_data_add_assets_data(
        kubecost_allocation_data_with_eks_cluster_name, kubecost_assets_data)

    # Transforming Kubecost's Allocation API data to a list of lists, and updating timestamps
    kubecost_updated_allocation_data = kubecost_allocation_data_timestamp_update(
        kubecost_allocation_data_with_assets_data)

    # Transforming Kubecost's updated allocation data to CSV, then to Parquet, compressing, and uploading it to S3
    kubecost_allocation_data_to_csv(kubecost_updated_allocation_data, columns)
    kubecost_csv_allocation_data_to_parquet("output.csv", LABELS)
    upload_kubecost_allocation_parquet_to_s3(S3_BUCKET_NAME, CLUSTER_ID, three_days_ago_date, three_days_ago_month,
                                             three_days_ago_year)


if __name__ == "__main__":
    main()
