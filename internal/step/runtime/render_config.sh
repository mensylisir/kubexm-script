#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: runtime_render_config
# 渲染容器运行时配置文件
# ==============================================================================

source "${KUBEXM_ROOT}/internal/runner/runner.sh"
source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

step::runtime.render.config::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::runtime.render.config "$@"
}

step::runtime.render.config() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=runtime.render_config] Rendering runtime config..."

  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      _render_containerd_config "${host}"
      ;;
    docker)
      _render_docker_config "${host}"
      ;;
    crio)
      _render_crio_config "${host}"
      ;;
    *)
      logger::error "[host=${host}] Unsupported runtime: ${runtime_type}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=runtime.render_config] Runtime config rendered"
  return 0
}

_render_containerd_config() {
  local host="$1"

  # 生成 containerd config.toml
  local registry_mirrors=""
  local sandbox_image=""

  # 从配置获取 registry mirrors
  registry_mirrors=$(config::get_registry_mirrors_json)
  sandbox_image=$(config::get_sandbox_image)

  # 渲染模板
  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/containerd/config.toml.tmpl" \
    "/etc/containerd/config.toml" \
    "registry_mirrors=${registry_mirrors}" \
    "sandbox_image=${sandbox_image}"

  logger::info "[host=${host}] Containerd config rendered to /etc/containerd/config.toml"
}

_render_docker_config() {
  local host="$1"

  # 生成 daemon.json
  local registry_mirrors=""
  registry_mirrors=$(config::get_registry_mirrors_json)

  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/docker/daemon.json.tmpl" \
    "/etc/docker/daemon.json" \
    "registry_mirrors=${registry_mirrors}"

  logger::info "[host=${host}] Docker config rendered to /etc/docker/daemon.json"
}

_render_crio_config() {
  local host="$1"

  # 生成 crio.conf
  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/crio/crio.conf.tmpl" \
    "/etc/crio/crio.conf"

  # 生成 registries.conf
  context::render_template "${host}" \
    "${KUBEXM_ROOT}/templates/runtime/crio/registries.conf.tmpl" \
    "/etc/containers/registries.conf"

  logger::info "[host=${host}] CRI-O config rendered"
}

step::runtime.render.config::check() {
  local runtime_type
  runtime_type=$(config::get_container_runtime)

  case "${runtime_type}" in
    containerd)
      if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/containerd/config.toml" && \
         runner::remote_exec "grep -q 'sandbox_image' /etc/containerd/config.toml" >/dev/null 2>&1; then
        return 0
      fi
      ;;
    docker)
      if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/docker/daemon.json"; then
        return 0
      fi
      ;;
    crio)
      if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/crio/crio.conf" && \
         step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/containers/registries.conf"; then
        return 0
      fi
      ;;
  esac
  return 1
}

step::runtime.render.config::rollback() { return 0; }

step::runtime.render.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
