import argparse
import os
import sys
from pathlib import Path

from azure.identity import ClientSecretCredential
from fabric_cicd import FabricWorkspace, publish_all_items


ITEM_TYPES = [
     "SemanticModel",
    "Report",
     "DataPipeline",
     "Lakehouse",
]


def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True, choices=["TEST", "PROD"])
    parser.add_argument("--workspace-id", required=True)
    args = parser.parse_args()

    tenant_id = required_env("AZURE_TENANT_ID")
    client_id = required_env("AZURE_CLIENT_ID")
    client_secret = required_env("AZURE_CLIENT_SECRET")

    token_credential = ClientSecretCredential(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret,
    )

    repository_directory = Path.cwd()

    print(f"Deploying to environment: {args.environment}")
    print(f"Target workspace ID: {args.workspace_id}")
    print(f"Repository directory: {repository_directory}")
    print(f"Item types in scope: {ITEM_TYPES}")

    target_workspace = FabricWorkspace(
        workspace_id=args.workspace_id,
        environment=args.environment,
        repository_directory=str(repository_directory),
        item_type_in_scope=ITEM_TYPES,
        token_credential=token_credential,
    )

    publish_all_items(target_workspace)

    print(f"Deployment to {args.environment} completed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
