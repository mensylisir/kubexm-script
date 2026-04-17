#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.config::check() { return 1; }

step::images.push.collect.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/utils/utils.sh"

  local cluster_name target_registry push_from_packages packages_dir
  cluster_name="$(context::get "images_push_cluster_name" || true)"
  target_registry="$(context::get "images_push_target_registry" || true)"
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  packages_dir="$(context::get "images_push_packages_dir" || true)"

  if [[ -n "$cluster_name" ]]; then
    export KUBEXM_CLUSTER_NAME="${cluster_name}"

    if [[ ! -f "$KUBEXM_CONFIG_FILE" ]]; then
      log::error "配置文件不存在: $KUBEXM_CONFIG_FILE"
      return 1
    fi

    config::parse_config

    if [[ -z "$target_registry" ]]; then
      local registry_host
      registry_host=$(config::get_registry_host)
      local registry_port
      registry_port=$(config::get_registry_port)
      if [[ -n "$registry_host" ]]; then
        target_registry="${registry_host}:${registry_port:-5000}"
      else
        log::error "未找到Registry主机，请配置 spec.registry.host 或 registry 角色节点"
        return 1
      fi
    fi

    log::info "推送镜像到集群Registry: $cluster_name"
    config::show_summary
  else
    if [[ -z "$target_registry" ]]; then
      log::error "未指定目标Registry，请使用 --target-registry= 或 --cluster=NAME"
      return 1
    fi
  fi

  if [[ "$push_from_packages" == "true" && -z "$packages_dir" ]]; then
    packages_dir="${KUBEXM_ROOT}/packages/images"
  fi

  # 离线推送优先使用本地 tools/common 的 skopeo
  if [[ "$push_from_packages" == "true" ]]; then
    if ! command -v skopeo &>/dev/null; then
      local arch skopeo_path
      arch="$(utils::get_arch)"
      skopeo_path="${KUBEXM_ROOT}/packages/tools/common/${arch}/skopeo"
      if [[ -f "${skopeo_path}" ]]; then
        chmod +x "${skopeo_path}" || true
        mkdir -p "${KUBEXM_ROOT}/bin"
        ln -sf "${skopeo_path}" "${KUBEXM_ROOT}/bin/skopeo"
        export PATH="${KUBEXM_ROOT}/bin:${KUBEXM_ROOT}/packages/tools/common/${arch}:${PATH}"
        log::info "使用离线skopeo: ${skopeo_path}"
      fi
    fi
  fi

  context::set "images_push_target_registry" "${target_registry}"
  context::set "images_push_packages_dir" "${packages_dir}"
}

step::images.push.collect.config::rollback() { return 0; }

step::images.push.collect.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
