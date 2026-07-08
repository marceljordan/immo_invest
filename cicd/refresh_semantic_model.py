import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from azure.identity import ClientSecretCredential

API_BASE = "https://api.powerbi.com/v1.0/myorg"


def get_token(tenant_id, client_id, client_secret):
    credential = ClientSecretCredential(tenant_id, client_id, client_secret)
    return credential.get_token("https://analysis.windows.net/powerbi/api/.default").token


def api_request(url, token, method="GET", data=None):
    headers = {"Authorization": f"Bearer {token}"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        raise Exception(f"Appel Power BI échoué ({method} {url}): {e.code} {e.read().decode()}") from e


def get_dataset_id(group_id, dataset_name, token):
    _, body = api_request(f"{API_BASE}/groups/{group_id}/datasets", token)
    datasets = json.loads(body).get("value", [])
    for dataset in datasets:
        if dataset["name"] == dataset_name:
            return dataset["id"]
    names = [d["name"] for d in datasets]
    raise Exception(f"Dataset '{dataset_name}' introuvable. Datasets visibles: {names}")


def refresh(group_id, dataset_id, token):
    status, _ = api_request(
        f"{API_BASE}/groups/{group_id}/datasets/{dataset_id}/refreshes",
        token,
        method="POST",
        data=b"{}",
    )
    print(f"Refresh déclenché. Status: {status}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--group-id", required=True)
    parser.add_argument("--dataset-name", required=True)
    args = parser.parse_args()

    token = get_token(
        os.environ["AZURE_TENANT_ID"],
        os.environ["AZURE_CLIENT_ID"],
        os.environ["AZURE_CLIENT_SECRET"],
    )

    dataset_id = get_dataset_id(args.group_id, args.dataset_name, token)
    print(f"Dataset '{args.dataset_name}' trouvé: {dataset_id}")
    refresh(args.group_id, dataset_id, token)
    return 0


if __name__ == "__main__":
    sys.exit(main())
