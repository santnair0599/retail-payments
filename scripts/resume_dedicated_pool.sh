#!/usr/bin/env bash
# Run this at the start of a session, before running any Dedicated Pool SQL.
set -euo pipefail

RESOURCE_GROUP="${1:?Usage: resume_dedicated_pool.sh <resource-group> <synapse-workspace-name> <pool-name>}"
WORKSPACE_NAME="${2:?Usage: resume_dedicated_pool.sh <resource-group> <synapse-workspace-name> <pool-name>}"
POOL_NAME="${3:?Usage: resume_dedicated_pool.sh <resource-group> <synapse-workspace-name> <pool-name>}"

echo "Resuming Dedicated SQL Pool '$POOL_NAME' in workspace '$WORKSPACE_NAME'..."
az synapse sql pool resume \
  --name "$POOL_NAME" \
  --workspace-name "$WORKSPACE_NAME" \
  --resource-group "$RESOURCE_GROUP"

echo "Resume requested — this takes a few minutes. Poll status with:"
echo "az synapse sql pool show --name $POOL_NAME --workspace-name $WORKSPACE_NAME --resource-group $RESOURCE_GROUP --query status -o tsv"
