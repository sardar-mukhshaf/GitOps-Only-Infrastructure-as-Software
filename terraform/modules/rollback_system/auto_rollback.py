"""
Auto-Rollback Lambda
Triggered by ArgoCD sync failure events.
Reverts the last commit that caused the failure in staging.
For prod, creates a PagerDuty incident requiring manual approval.
"""
import json
import os
import boto3
import urllib.request
import urllib.error

GITHUB_TOKEN_SECRET_ARN = os.environ.get("GITHUB_TOKEN_SECRET_ARN", "")
PAGERDUTY_SERVICE_KEY = os.environ.get("PAGERDUTY_SERVICE_KEY", "")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")
ENABLE_AUTO_REVERT_STAGING = os.environ.get("ENABLE_AUTO_REVERT_STAGING", "false").lower() == "true"

secretsmanager = boto3.client("secretsmanager")


def get_github_token():
    if not GITHUB_TOKEN_SECRET_ARN:
        return None
    response = secretsmanager.get_secret_value(SecretId=GITHUB_TOKEN_SECRET_ARN)
    secret = json.loads(response["SecretString"])
    return secret.get("github_token")


def revert_commit(repo, sha, token):
    """Create a revert commit for the given SHA."""
    url = f"https://api.github.com/repos/{repo}/git/commits/{sha}"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        commit_data = json.loads(response.read())

    parent_sha = commit_data["parents"][0]["sha"]
    tree_sha = commit_data["tree"]["sha"]
    message = f'Revert "{commit_data["message"]}"\n\nThis reverts commit {sha} due to ArgoCD sync failure.'

    # Create new commit
    create_commit_url = f"https://api.github.com/repos/{repo}/git/commits"
    commit_payload = json.dumps({
        "message": message,
        "parents": [parent_sha],
        "tree": tree_sha
    }).encode()

    req = urllib.request.Request(create_commit_url, data=commit_payload, headers=headers)
    with urllib.request.urlopen(req) as response:
        new_commit = json.loads(response.read())

    # Update branch reference
    default_branch = commit_data.get("commit", {}).get("url", "").split("/")[-3] if "url" in commit_data else "main"
    ref_url = f"https://api.github.com/repos/{repo}/git/refs/heads/{default_branch}"
    ref_payload = json.dumps({"sha": new_commit["sha"]}).encode()

    req = urllib.request.Request(ref_url, data=ref_payload, headers=headers, method="PATCH")
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())


def create_pagerduty_incident(summary, details):
    """Create a PagerDuty incident for production failures."""
    if not PAGERDUTY_SERVICE_KEY:
        print("No PagerDuty service key configured")
        return None

    url = "https://events.pagerduty.com/v2/enqueue"
    payload = json.dumps({
        "routing_key": PAGERDUTY_SERVICE_KEY,
        "event_action": "trigger",
        "payload": {
            "summary": summary,
            "severity": "critical",
            "source": "argocd-auto-rollback",
            "custom_details": details
        }
    }).encode()

    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as e:
        print(f"PagerDuty API error: {e.read().decode()}")
        return None


def lambda_handler(event, context):
    print("Auto-rollback triggered")
    print(json.dumps(event))

    message = json.loads(event["Records"][0]["Sns"]["Message"])
    app_name = message.get("app", "unknown")
    sync_status = message.get("syncStatus", "Unknown")
    commit_sha = message.get("revision", "")
    repo = message.get("repo", "")

    if ENVIRONMENT == "prod":
        incident = create_pagerduty_incident(
            f"ArgoCD sync failure in prod: {app_name}",
            {
                "app": app_name,
                "commit": commit_sha,
                "syncStatus": sync_status,
                "environment": ENVIRONMENT,
                "action": "Manual approval required for revert"
            }
        )
        print(f"Production sync failure - PagerDuty incident created: {incident}")
        return {
            "statusCode": 200,
            "body": json.dumps({"action": "pagerduty_alert", "incident": incident})
        }

    if ENVIRONMENT == "staging" and ENABLE_AUTO_REVERT_STAGING:
        token = get_github_token()
        if token and repo and commit_sha:
            try:
                result = revert_commit(repo, commit_sha, token)
                print(f"Reverted commit {commit_sha}: {result}")
                return {
                    "statusCode": 200,
                    "body": json.dumps({"action": "revert", "result": result})
                }
            except Exception as e:
                print(f"Revert failed: {e}")
                raise
        else:
            print("Missing token, repo, or commit SHA - cannot auto-revert")
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing required parameters for revert"})
            }

    print(f"Auto-revert not enabled for environment {ENVIRONMENT}")
    return {
        "statusCode": 200,
        "body": json.dumps({"action": "none", "reason": "auto-revert not enabled"})
    }
