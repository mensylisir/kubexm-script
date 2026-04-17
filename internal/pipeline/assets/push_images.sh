#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/images.sh"

pipeline::push_images() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="push.images"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning push images pipeline"
    return 0
  fi

  local cluster_name=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --packages|--packages-dir=*)
        export KUBEXM_REQUIRE_PACKAGES="true"
        ;;
      --manifest)
        export KUBEXM_TOOL_CHECKS="${KUBEXM_TOOL_CHECKS} manifest-tool"
        ;;
    esac
  done

  if [[ -n "${cluster_name}" ]]; then
    export KUBEXM_CLUSTER_NAME="${cluster_name}"
    if [[ -f "${KUBEXM_CONFIG_FILE}" ]]; then
      parser::load_config
    fi
    if [[ -f "${KUBEXM_HOST_FILE}" ]]; then
      parser::load_hosts
    fi
  fi

  # 检查工具
  KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq skopeo"
  module::check_tools "${ctx}" "$@" || return $?

  # 执行推送流程
  module::push_images "${ctx}" "$@"
}