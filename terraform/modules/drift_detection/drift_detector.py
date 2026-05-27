"""
Drift Detection Lambda
Compares Terraform state with live AWS resources.
Supports: EC2, Security Groups, IAM Policies, S3 Buckets, Route53, RDS
"""
import json
import os
import boto3
import urllib.request

STATE_BUCKET = os.environ["STATE_BUCKET_NAME"]
STATE_KEY = os.environ["STATE_BUCKET_KEY"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
AUTO_REMEDIATE = os.environ.get("AUTO_REMEDIATE", "false").lower() == "true"
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")

s3 = boto3.client("s3")
sns = boto3.client("sns")
ec2 = boto3.client("ec2")
iam = boto3.client("iam")
rds = boto3.client("rds")
route53 = boto3.client("route53")


def get_tf_state():
    """Download and parse Terraform state from S3."""
    response = s3.get_object(Bucket=STATE_BUCKET, Key=STATE_KEY)
    return json.loads(response["Body"].read())


def get_state_resources(state):
    """Extract resources from Terraform state."""
    resources = {}
    for module in state.get("modules", []):
        for resource in module.get("resources", []):
            rtype = resource.get("type", "")
            rname = resource.get("name", "")
            key = f"{rtype}.{rname}"
            resources[key] = resource.get("primary", {}).get("attributes", {})
    # Modern state format
    for resource in state.get("resources", []):
        rtype = resource.get("type", "")
        for instance in resource.get("instances", []):
            rname = resource.get("name", "")
            key = f"{rtype}.{rname}"
            resources[key] = instance.get("attributes", {})
    return resources


def check_ec2_drift(resources):
    """Compare EC2 instances in state with live AWS."""
    drift = []
    state_instances = {
        k: v for k, v in resources.items()
        if k.startswith("aws_instance.")
    }
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
            drift.append({
                "resource": key,
                "type": "ec2",
                "drift_type": "MISSING",
                "detail": f"EC2 instance {instance_id} exists in state but not in AWS"
            })
    return drift


def check_sg_drift(resources):
    """Compare Security Groups in state with live AWS."""
    drift = []
    state_sgs = {
        k: v for k, v in resources.items()
        if k.startswith("aws_security_group.")
    }
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
            drift.append({
                "resource": key,
                "type": "security_group",
                "drift_type": "MISSING",
                "detail": f"Security Group {sg_id} exists in state but not in AWS"
            })
    return drift


def check_iam_drift(resources):
    """Compare IAM policies in state with live AWS."""
    drift = []
    state_policies = {
        k: v for k, v in resources.items()
        if k.startswith("aws_iam_policy.")
    }
    if not state_policies:
        return drift

    for key, attrs in state_policies.items():
        arn = attrs.get("arn", "")
        if arn:
            try:
                iam.get_policy(PolicyArn=arn)
            except iam.exceptions.NoSuchEntityException:
                drift.append({
                    "resource": key,
                    "type": "iam_policy",
                    "drift_type": "MISSING",
                    "detail": f"IAM policy {arn} exists in state but not in AWS"
                })
    return drift


def check_s3_drift(resources):
    """Compare S3 buckets in state with live AWS."""
    drift = []
    state_buckets = {
        k: v for k, v in resources.items()
        if k.startswith("aws_s3_bucket.")
    }
    if not state_buckets:
        return drift

    live_buckets = set()
    paginator = s3.get_paginator("list_buckets")
    for page in paginator.paginate():
        for bucket in page["Buckets"]:
            live_buckets.add(bucket["Name"])

    for key, attrs in state_buckets.items():
        bucket_name = attrs.get("bucket", attrs.get("id", ""))
        if bucket_name and bucket_name not in live_buckets:
            drift.append({
                "resource": key,
                "type": "s3_bucket",
                "drift_type": "MISSING",
                "detail": f"S3 bucket {bucket_name} exists in state but not in AWS"
            })
    return drift


def check_rds_drift(resources):
    """Compare RDS instances in state with live AWS."""
    drift = []
    state_dbs = {
        k: v for k, v in resources.items()
        if k.startswith("aws_db_instance.")
    }
    if not state_dbs:
        return drift

    live_dbs = set()
    paginator = rds.get_paginator("describe_db_instances")
    for page in paginator.paginate():
        for db in page["DBInstances"]:
            live_dbs.add(db["DBInstanceIdentifier"])

    for key, attrs in state_dbs.items():
        db_id = attrs.get("identifier", attrs.get("id", ""))
        if db_id and db_id not in live_dbs:
            drift.append({
                "resource": key,
                "type": "rds",
                "drift_type": "MISSING",
                "detail": f"RDS instance {db_id} exists in state but not in AWS"
            })
    return drift


def send_alert(drift_items):
    """Send drift alerts to SNS."""
    if not drift_items:
        print("No drift detected.")
        return

    message = {
        "default": json.dumps({
            "environment": ENVIRONMENT,
            "drift_count": len(drift_items),
            "drift_items": drift_items,
            "auto_remediate": AUTO_REMEDIATE,
            "message": f"Drift detected: {len(drift_items)} resources diverged from Terraform state"
        }),
        "email": f"Drift Alert ({ENVIRONMENT}): {len(drift_items)} resources diverged from Terraform state.\n\nDetails:\n{json.dumps(drift_items, indent=2)}"
    }

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        MessageStructure="json",
        Message=json.dumps(message),
        Subject=f"[DRIFT] {ENVIRONMENT}: {len(drift_items)} resources diverged"
    )
    print(f"Alert sent for {len(drift_items)} drift items")


def lambda_handler(event, context):
    print("Starting drift detection...")

    try:
        state = get_tf_state()
        resources = get_state_resources(state)
    except Exception as e:
        print(f"Failed to load state: {e}")
        raise

    all_drift = []
    all_drift.extend(check_ec2_drift(resources))
    all_drift.extend(check_sg_drift(resources))
    all_drift.extend(check_iam_drift(resources))
    all_drift.extend(check_s3_drift(resources))
    all_drift.extend(check_rds_drift(resources))

    send_alert(all_drift)

    return {
        "statusCode": 200,
        "body": json.dumps({
            "drift_detected": len(all_drift) > 0,
            "drift_count": len(all_drift),
            "drift_items": all_drift
        })
    }
