#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# System Check Task - Main
# ==============================================================================

source "${KUBEXM_ROOT}/internal/step/lib/registry.sh"
source "${KUBEXM_ROOT}/internal/parser/parser.sh"
source "${KUBEXM_ROOT}/internal/step/lib/step_runner.sh"

task::system_check() {
  local ctx="$1"
  shift
  local args=("$@")
  local cluster_name=""
  local arg
  for arg in "${args[@]}"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  if [[ ! -f "${KUBEXM_CONFIG_FILE}" ]]; then
    echo "config.yaml not found: ${KUBEXM_CONFIG_FILE}" >&2
    return 1
  fi
  if [[ ! -f "${KUBEXM_HOST_FILE}" ]]; then
    echo "host.yaml not found: ${KUBEXM_HOST_FILE}" >&2
    return 1
  fi
  parser::load_config
  parser::load_hosts
  export KUBEXM_REQUIRE_PACKAGES="true"
  task::run_steps "${ctx}" "${args[@]}" -- \
    "check.tools.binary:${KUBEXM_ROOT}/internal/step/common/checks/check_tools_binary.sh" \
    "check.tools.packages:${KUBEXM_ROOT}/internal/step/common/checks/check_tools_packages.sh" \
    "check.os:${KUBEXM_ROOT}/internal/step/common/checks/check_os.sh" \
    "check.resources:${KUBEXM_ROOT}/internal/step/common/checks/check_resources.sh"

  return 0
}

export -f task::system_check