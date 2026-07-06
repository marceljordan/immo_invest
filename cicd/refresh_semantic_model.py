import argparse
import os
import requests
from azure.identity import ClientSecretCredential


def get_token(tenant_id, client_id, client_secret):
    credential = ClientSecretCredential(tenant_id, client_id, client_secret)
    return credential.get_token("https://analysis.windows.net/powerbi/api/.default").token


def refresh(group_id, dataset_id, token):
    url = f"https://api.powerbi.com/v1.0/myorg/groups/{group_id}/datasets/{dataset_id}/refreshes"
    resp = requests.post(url, headers={"Authorization": f"Bearer {token}"})
    resp.raise_for_status()
    print(f"Refresh déclenché. Status: {resp.status_code}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--group-id", required=True)
    parser.add_argument("--dataset-id", required=True)
    args = parser.parse_args()

    token = get_token(
        os.environ["AZURE_TENANT_ID"],
        os.environ["AZURE_CLIENT_ID"],
        os.environ["AZURE_CLIENT_SECRET"],
    )
    refresh(args.group_id, args.dataset_id, token)


if __name__ == "__main__":
    main()
