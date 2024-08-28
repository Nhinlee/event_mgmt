#!/bin/bash

set -euo pipefail

source ./scripts/log.sh

function collect_run_time {
  loginfo "Deployment took: ${SECONDS} seconds"
}

# Start the local k8s cluster. Use delete_cluster to delete it.
function start_cluster() {
  echo "Starting kind cluster ..."
}

# Delete k8s cluster in local. Use start_cluster to start it again.
function delete_cluster() {
  echo "Deleting kind cluster ..."
}

start_cluster
collect_run_time
