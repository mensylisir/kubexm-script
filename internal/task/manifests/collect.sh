#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Manifests Task - Collect
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::manifests_collect() {
  local ctx="$1"
  shift || true
  local args=("$@")

  task::run_steps "${ctx}" "${args[@]}" -- \
    "manifests.collect.args:${KUBEXM_ROOT}/internal/task/manifests/manifests_collect_args.sh" \
    "manifests.collect.from.cluster.prepare:${KUBEXM_ROOT}/internal/task/manifests/manifests_collect_from_cluster_prepare.sh" \
    "manifests.collect.from.cluster.values:${KUBEXM_ROOT}/internal/task/manifests/manifests_collect_from_cluster_values.sh" \
    "manifests.collect.from.cluster.normalize:${KUBEXM_ROOT}/internal/task/manifests/manifests_collect_from_cluster_normalize.sh" \
    "manifests.collect.defaults:${KUBEXM_ROOT}/internal/task/manifests/manifests_collect_defaults.sh"
}

export -f task::manifests_collect