#!/usr/bin/env bash
# Run this at the end of EVERY session touching the Dedicated SQL Pool.
# Terraform does not and cannot auto-pause this resource for you — see the
# cost warning at the top of infra/terraform/synapse.tf.
set -euo pipefail

RESOURCE_GROUP="${1:?Usage: pause_dedicated_pool.sh <resource-group> <synapse-workspace-name> <pool-name>}"
WORKSPACE_NAME="${2:?Usage: pause_dedicated_pool.sh <resource-group> <synapse-workspace-name> <pool-name>}"
POOL_NAME="${3:?Usage: pause_dedicated_pool.sh <resource-group> <synapse-workspace-name> <pool-name>}"

echo "Pausing Dedicated SQL Pool '$POOL_NAME' in workspace '$WORKSPACE_NAME'..."
az synapse sql pool pause \
  --name "$POOL_NAME" \
  --workspace-name "$WORKSPACE_NAME" \
  --resource-group "$RESOURCE_GROUP"

echo "Pause requested. Check status with:"
echo "az synapse sql pool show --name $POOL_NAME --workspace-name $WORKSPACE_NAME --resource-group $RESOURCE_GROUP --query status -o tsv"
