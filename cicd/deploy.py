import argparse
import sys
from pathlib import Path

from fabric_cicd import FabricWorkspace, publish_all_items


ITEM_TYPES = [
    "Lakehouse",
    "Warehouse",
    "DataPipeline",
    "Dataflow",
    "Notebook",
    "SemanticModel",
    "Report",
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", required=True, choices=["TEST", "PROD"])
    parser.add_argument("--workspace-id", required=True)
    args = parser.parse_args()

    repo_root = Path.cwd()

    target_workspace = FabricWorkspace(
        workspace_id=args.workspace_id,
        item_repository_directory=str(repo_root),
        item_type_in_scope=ITEM_TYPES,
        environment=args.environment,
    )

    publish_all_items(target_workspace)

    print(f"Deployment to {args.environment} completed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
