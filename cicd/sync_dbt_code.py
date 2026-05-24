import argparse
import os
import sys
from pathlib import Path
from azure.identity import ClientSecretCredential
from azure.storage.filedatalake import DataLakeServiceClient

ONELAKE_ACCOUNT = "onelake.dfs.fabric.microsoft.com"

WORKSPACE_NAMES = {
    "TEST": "FAB-Immo-Test",
    "PROD": "FAB-Immo-Prod",
}

def get_credential(tenant_id, client_id, client_secret):
    return ClientSecretCredential(tenant_id, client_id, client_secret)

def sync_dbt_code(workspace_name, local_dbt_path, credential):
    service_client = DataLakeServiceClient(
        account_url=f"https://{ONELAKE_ACCOUNT}",
        credential=credential,
    )

    filesystem_client = service_client.get_file_system_client(workspace_name)

    local_path = Path(local_dbt_path)

    for file_path in local_path.rglob("*"):
        if file_path.is_file():
            relative_path = file_path.relative_to(local_path.parent)
            remote_path = f"dbt.DBTItem/Code/{relative_path}".replace("\\", "/")

            print(f"Uploading {relative_path} → {remote_path}")

            file_client = filesystem_client.get_file_client(remote_path)
            with open(file_path, "rb") as f:
                file_client.upload_data(f.read(), overwrite=True)

    print(f"Sync dbt code terminé vers {workspace_name}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True, choices=["TEST", "PROD"])
    parser.add_argument("--dbt-path", required=True, help="Chemin local vers le dossier dbt")
    args = parser.parse_args()

    credential = get_credential(
        os.environ["AZURE_TENANT_ID"],
        os.environ["AZURE_CLIENT_ID"],
        os.environ["AZURE_CLIENT_SECRET"],
    )

    workspace_name = WORKSPACE_NAMES[args.environment]
    sync_dbt_code(workspace_name, args.dbt_path, credential)
    return 0

if __name__ == "__main__":
    sys.exit(main())
