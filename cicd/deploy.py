import argparse
import os
import sys
from pathlib import Path
from azure.identity import ClientSecretCredential
from fabric_cicd import FabricWorkspace, publish_all_items

ITEM_TYPES = [
    "SemanticModel",
    "Report",
    "Notebook",
    "DataPipeline",
    "Environment"
]

EXISTING_ITEMS = {
    "TEST": {
        "Lakehouse": [
            {"name": "LH_Immo_Test", "id": "ff9a675e-9109-40a6-918c-d73603f1817b"}
        ],
        "Warehouse": [
            {"name": "WH_Immo_Test", "id": "ae06833d-ca01-4987-b3d9-29b04c2b29a0"}
        ],
    },
    "PROD": {
        "Lakehouse": [
            {"name": "LH_Immo_Prod", "id": "376ce754-158f-4705-8e15-cfa1215b2667"}
        ],
        "Warehouse": [
            {"name": "WH_Immo_Prod", "id": "ff295195-4e19-44ec-93f8-60da368f1689"}
        ],
    },
}

def required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value
import requests

def set_default_environment(workspace_id: str, environment_name: str, runtime_version: str, token: str):
    """Définit un Environment comme Workspace default via l'API REST Fabric.
    Doit être appelé APRÈS publish_all_items() : l'item Environment doit déjà exister
    dans le workspace cible pour que le nom soit résolvable."""
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/spark/settings"
    resp = requests.patch(
        url,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={
            "environment": {
                "name": environment_name,
                "runtimeVersion": runtime_version,
            }
        },
    )
    resp.raise_for_status()
    print(f"✅ Environment '{environment_name}' défini comme default sur {workspace_id}")
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
        existing_items=EXISTING_ITEMS[args.environment],
    )

    semantic_model_binding = target_workspace.environment_parameter.get("semantic_model_binding")
    if "SemanticModel" in target_workspace.item_type_in_scope and not semantic_model_binding:
        print(
            "Warning: no semantic_model_binding found in parameter.yml. "
            "Skipping SemanticModel deployment to preserve existing Warehouse connection credentials."
        )
        target_workspace.item_type_in_scope = [
            item_type for item_type in target_workspace.item_type_in_scope if item_type != "SemanticModel"
        ]

    publish_all_items(target_workspace)
    # token = token_credential.get_token("https://api.fabric.microsoft.com/.default").token
    # set_default_environment(
    #     workspace_id=args.workspace_id,
    #     environment_name="env",
    #     runtime_version="1.3",
    #     token=token,
    # )
    print(f"Deployment to {args.environment} completed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
