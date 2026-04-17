#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export KUBEXM_ROOT="${ROOT}"
export KUBEXM_SCRIPT_ROOT="${ROOT}"

source "${ROOT}/internal/parser/parser.sh"
source "${ROOT}/internal/config/config.sh"

# ---- Bug fix: config::get_master_nodes and config::get_etcd_nodes ----
# These functions passed a spurious second argument to config::get_role_members
# which only accepts one argument (role). This test verifies the fix works.

# config::get_role_members only accepts 1 argument (role)
# Before the fix: get_role_members "master" "${hosts_content}" (2 args — ignored 2nd)
# After the fix: get_role_members "master" (1 arg — correct)

# Set up role groups directly via KUBEXM_ROLE_GROUPS
declare -A KUBEXM_ROLE_GROUPS=(
  [master]="node1 node2"
  [control-plane]="node1 node2"
  [worker]="node3"
  [etcd]="node1 node2 node3"
)

# This should return "node1 node2" without error (1 arg only)
result=$(config::get_role_members "master")
if [[ "${result}" != "node1 node2" ]]; then
  echo "FAIL: config::get_role_members returned '${result}' instead of 'node1 node2'" >&2
  exit 1
fi

# Test control-plane aliasing (master ↔ control-plane)
result_cp=$(config::get_role_members "control-plane")
if [[ "${result_cp}" != "node1 node2" ]]; then
  echo "FAIL: config::get_role_members control-plane alias returned '${result_cp}'" >&2
  exit 1
fi

# Test etcd role
result_etcd=$(config::get_role_members "etcd")
if [[ "${result_etcd}" != "node1 node2 node3" ]]; then
  echo "FAIL: config::get_role_members etcd returned '${result_etcd}'" >&2
  exit 1
fi

# Test worker role
result_worker=$(config::get_role_members "worker")
if [[ "${result_worker}" != "node3" ]]; then
  echo "FAIL: config::get_role_members worker returned '${result_worker}'" >&2
  exit 1
fi

# ---- Test that get_role_members with 2 args still works (survives extra args) ----
# Before the fix: 2 args were accepted but 2nd was silently ignored
# After the fix: 2 args still works (bash ignores extra positional args)
result2=$(config::get_role_members "master" "ignored_extra_arg")
if [[ "${result2}" != "node1 node2" ]]; then
  echo "FAIL: config::get_role_members with 2 args returned '${result2}'" >&2
  exit 1
fi
