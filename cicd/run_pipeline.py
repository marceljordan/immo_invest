import argparse
import json
import os
import sys
import time
import urllib.request
from azure.identity import ClientSecretCredential

def get_token(tenant_id, client_id, client_secret):
    credential = ClientSecretCredential(tenant_id, client_id, client_secret)
    return credential.get_token("https://api.fabric.microsoft.com/.default").token

def get_pipeline_id(workspace_id, pipeline_name, token):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items?type=DataPipeline"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        items = json.loads(resp.read()).get("value", [])
    for item in items:
        if item["displayName"] == pipeline_name:
            return item["id"]
    raise Exception(f"Pipeline '{pipeline_name}' not found")

def run_pipeline(workspace_id, pipeline_id, token):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items/{pipeline_id}/jobs/instances?jobType=Pipeline"
    req = urllib.request.Request(
        url,
        data=b"{}",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req) as resp:
        location = resp.headers.get("Location")
        print(f"Pipeline démarré. Job URL: {location}")
        return location

def wait_for_completion(location, token, timeout=3600):
    start = time.time()
    while time.time() - start < timeout:
        req = urllib.request.Request(location, headers={"Authorization": f"Bearer {token}"})
        with urllib.request.urlopen(req) as resp:
            job = json.loads(resp.read())
        status = job.get("status")
        print(f"Status: {status}")
        if status == "Completed":
            print("Pipeline terminé avec succès.")
            return
        elif status in ("Failed", "Cancelled"):
            raise Exception(f"Pipeline échoué avec status: {status}")
        time.sleep(30)
    raise Exception("Timeout — pipeline trop long")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workspace-id", required=True)
    parser.add_argument("--pipeline-name", required=True)
    args = parser.parse_args()

    token = get_token(
        os.environ["AZURE_TENANT_ID"],
        os.environ["AZURE_CLIENT_ID"],
        os.environ["AZURE_CLIENT_SECRET"],
    )

    pipeline_id = get_pipeline_id(args.workspace_id, args.pipeline_name, token)
    location = run_pipeline(args.workspace_id, pipeline_id, token)
    wait_for_completion(location, token)
    return 0

if __name__ == "__main__":
    sys.exit(main())
