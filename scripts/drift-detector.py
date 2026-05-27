#!/usr/bin/env python3
"""
Standalone drift detection script.
Can be run locally or as a Lambda function.
Compares Terraform state with live AWS resources.
"""
import json
import os
import sys
import boto3
import argparse


def load_state_from_s3(bucket, key):
    s3 = boto3.client("s3")
    response = s3.get_object(Bucket=bucket, Key=key)
    return json.loads(response["Body"].read())


def get_state_resources(state):
    resources = {}
    for resource in state.get("resources", []):
        rtype = resource.get("type", "")
        for instance in resource.get("instances", []):
            rname = resource.get("name", "")
            key = f"{rtype}.{rname}"
            resources[key] = instance.get("attributes", {})
    return resources


def check_ec2_drift(resources):
    drift = []
    ec2 = boto3.client("ec2")
    state_instances = {k: v for k, v in resources.items() if k.startswith("aws_instance.")}
    if not state_instances:
        return drift

    live_ids = set()
    paginator = ec2.get_paginator("describe_instances")
    for page in paginator.paginate():
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                if instance["State"]["Name"] != "terminated":
                    live_ids.add(instance["InstanceId"])

    for key, attrs in state_instances.items():
        instance_id = attrs.get("id", "")
        if instance_id and instance_id not in live_ids:
            drift.append({"resource": key, "type": "ec2", "drift_type": "MISSING",
                          "detail": f"EC2 instance {instance_id} missing in AWS"})
    return drift


def check_sg_drift(resources):
    drift = []
    ec2 = boto3.client("ec2")
    state_sgs = {k: v for k, v in resources.items() if k.startswith("aws_security_group.")}
    if not state_sgs:
        return drift

    live_sgs = {}
    paginator = ec2.get_paginator("describe_security_groups")
    for page in paginator.paginate():
        for sg in page["SecurityGroups"]:
            live_sgs[sg["GroupId"]] = sg

    for key, attrs in state_sgs.items():
        sg_id = attrs.get("id", "")
        if sg_id and sg_id not in live_sgs:
            drift.append({"resource": key, "type": "security_group", "drift_type": "MISSING",
                          "detail": f"Security Group {sg_id} missing in AWS"})
    return drift


def check_iam_drift(resources):
    drift = []
    iam = boto3.client("iam")
    state_policies = {k: v for k, v in resources.items() if k.startswith("aws_iam_policy.")}
    for key, attrs in state_policies.items():
        arn = attrs.get("arn", "")
        if arn:
            try:
                iam.get_policy(PolicyArn=arn)
            except iam.exceptions.NoSuchEntityException:
                drift.append({"resource": key, "type": "iam_policy", "drift_type": "MISSING",
                              "detail": f"IAM policy {arn} missing in AWS"})
    return drift


def check_s3_drift(resources):
    drift = []
    s3 = boto3.client("s3")
    state_buckets = {k: v for k, v in resources.items() if k.startswith("aws_s3_bucket.")}
    live_buckets = set()
    for page in s3.get_paginator("list_buckets").paginate():
        for bucket in page["Buckets"]:
            live_buckets.add(bucket["Name"])

    for key, attrs in state_buckets.items():
        bucket_name = attrs.get("bucket", attrs.get("id", ""))
        if bucket_name and bucket_name not in live_buckets:
            drift.append({"resource": key, "type": "s3_bucket", "drift_type": "MISSING",
                          "detail": f"S3 bucket {bucket_name} missing in AWS"})
    return drift


def check_rds_drift(resources):
    drift = []
    rds = boto3.client("rds")
    state_dbs = {k: v for k, v in resources.items() if k.startswith("aws_db_instance.")}
    live_dbs = set()
    for page in rds.get_paginator("describe_db_instances").paginate():
        for db in page["DBInstances"]:
            live_dbs.add(db["DBInstanceIdentifier"])

    for key, attrs in state_dbs.items():
        db_id = attrs.get("identifier", attrs.get("id", ""))
        if db_id and db_id not in live_dbs:
            drift.append({"resource": key, "type": "rds", "drift_type": "MISSING",
                          "detail": f"RDS instance {db_id} missing in AWS"})
    return drift


def main():
    parser = argparse.ArgumentParser(description="Detect drift between Terraform state and live AWS resources")
    parser.add_argument("--bucket", required=True, help="S3 bucket containing Terraform state")
    parser.add_argument("--key", required=True, help="S3 key for Terraform state file")
    parser.add_argument("--output", default="drift-report.json", help="Output file for drift report")
    args = parser.parse_args()

    print(f"Loading state from s3://{args.bucket}/{args.key}")
    state = load_state_from_s3(args.bucket, args.key)
    resources = get_state_resources(state)

    all_drift = []
    all_drift.extend(check_ec2_drift(resources))
    all_drift.extend(check_sg_drift(resources))
    all_drift.extend(check_iam_drift(resources))
    all_drift.extend(check_s3_drift(resources))
    all_drift.extend(check_rds_drift(resources))

    report = {
        "drift_detected": len(all_drift) > 0,
        "drift_count": len(all_drift),
        "drift_items": all_drift
    }

    with open(args.output, "w") as f:
        json.dump(report, f, indent=2)

    print(f"Drift check complete. {len(all_drift)} items found.")
    print(f"Report saved to {args.output}")

    if all_drift:
        sys.exit(1)


if __name__ == "__main__":
    main()
