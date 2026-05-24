import argparse
import json
import os
import sys
from azure.identity import ClientSecretCredential
import urllib.request

WORKSPACE_IDS = {
    "TEST": "c73a035a-8d64-4422-927c-bc9087c1176f",
    "PROD": "1c63902c-2435-4242-821f-08a1e2f019a0",
}

WAREHOUSE_IDS = {
    "TEST": "ae06833d-ca01-4987-b3d9-29b04c2b29a0",
    "PROD": "ff295195-4e19-44ec-93f8-60da368f1689",
}

WAREHOUSE_ENDPOINTS = {
    "TEST": "fri4w75fytzuhcdanfxmnvidla-libtvr3erurejet4xsiipqixn4.datawarehouse.fabric.microsoft.com",
    "PROD": "fri4w75fytzuhcdanfxmnvidla-fsigghbverbefaq7bcq6f4azua.datawarehouse.fabric.microsoft.com",
}

WAREHOUSE_NAMES = {
    "TEST": "WH_Immo_Test",
    "PROD": "WH_Immo_Prod",
}


def get_token(tenant_id, client_id, client_secret):
    credential = ClientSecretCredential(tenant_id, client_id, client_secret)
    token = credential.get_token("https://api.fabric.microsoft.com/.default")
    return token.token


def fabric_request(method, url, token, body=None):
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    with urllib.request.urlopen(req) as resp:
        content = resp.read()
        return json.loads(content) if content else None


def get_dbt_item_id(workspace_id, token):
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items?type=DataBuildToolJob"
    result = fabric_request("GET", url, token)
    for item in result.get("value", []):
        if item["displayName"] == "dbt":
            return item["id"]
    return None


def build_definition(env):
    definition = {
        "project": {
            "projectType": "OneLake",
            "folderPath": "dbt"
        },
        "profile": {
            "profileType": "DataWarehouse",
            "schema": "silver",
            "connectionSettings": {
                "name": WAREHOUSE_NAMES[env],
                "properties": {
                    "type": "DataWarehouse",
                    "typeProperties": {
                        "workspaceId": WORKSPACE_IDS[env],
                        "artifactId": WAREHOUSE_IDS[env],
                        "endPoint": WAREHOUSE_ENDPOINTS[env]
                    }
                }
            }
        },
        "command": {
            "operation": "build",
            "arguments": {
                "exclude": "",
                "threads": 4
            }
        }
    }
    return __import__("base64").b64encode(
        json.dumps(definition).encode()
    ).decode()


def create_dbt_job(workspace_id, env, token):
    body = {
        "displayName": "dbt",
        "type": "DataBuildToolJob",
        "definition": {
            "parts": [
                {
                    "path": "dbt-content.json",
                    "payload": build_definition(env),
                    "payloadType": "InlineBase64"
                }
            ]
        }
    }
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items"
    fabric_request("POST", url, token, body)
    print(f"dbt job créé dans workspace {workspace_id}")


def update_dbt_job(workspace_id, item_id, env, token):
    body = {
        "definition": {
            "parts": [
                {
                    "path": "dbt-content.json",
                    "payload": build_definition(env),
                    "payloadType": "InlineBase64"
                }
            ]
        }
    }
    url = f"https://api.fabric.microsoft.com/v1/workspaces/{workspace_id}/items/{item_id}/updateDefinition"
    fabric_request("POST", url, token, body)
    print(f"dbt job mis à jour dans workspace {workspace_id}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True, choices=["TEST", "PROD"])
    parser.add_argument("--workspace-id", required=True)
    args = parser.parse_args()

    token = get_token(
        os.environ["AZURE_TENANT_ID"],
        os.environ["AZURE_CLIENT_ID"],
        os.environ["AZURE_CLIENT_SECRET"],
    )

    item_id = get_dbt_item_id(args.workspace_id, token)

    if item_id:
        print(f"dbt job existant trouvé ({item_id}), mise à jour...")
        update_dbt_job(args.workspace_id, item_id, args.environment, token)
    else:
        print("dbt job non trouvé, création...")
        create_dbt_job(args.workspace_id, args.environment, token)

    print(f"Déploiement dbt terminé pour {args.environment}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
