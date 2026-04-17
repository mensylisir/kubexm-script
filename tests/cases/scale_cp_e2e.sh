#!/usr/bin/env bash
set -euo pipefail
export KUBEXM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Test: verify all CP scale steps are registered and syntax-valid
for step_file in \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_collect_action.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_collect_node.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_collect_command.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_join_exec.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_drain_nodes.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_remove_nodes.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_stop_kubelet.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_kubeadm_reset.sh" \
  "${KUBEXM_ROOT}/internal/task/cluster/cluster_scale_cp_cleanup_dirs.sh"; do
  [[ -f "${step_file}" ]] || { echo "missing ${step_file}"; exit 1; }
  bash -n "${step_file}" || { echo "syntax error in ${step_file}"; exit 1; }
done

# Test: verify task file has all registrations (now in common.sh)
grep -q "cluster.scale_cp_join_collect_action" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_join_exec" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_drain_nodes" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_remove_nodes" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_stop_kubelet" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_kubeadm_reset" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }
grep -q "cluster.scale_cp_cleanup_dirs" "${KUBEXM_ROOT}/internal/task/common.sh" || { echo "missing registration"; exit 1; }

echo "All CP scale steps verified"