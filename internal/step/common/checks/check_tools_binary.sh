#!/usr/bin/env bash
set -euo pipefail

# 配置依赖：统一在文件顶部加载，避免 check()/run() 每次调用重复 source
source "${KUBEXM_ROOT}/internal/utils/common.sh"

step::check.tools.binary::check() {
  local tools="jq yq xmjq xmyq xmparser xmrender"
  if [[ -n "${KUBEXM_TOOL_CHECKS:-}" ]]; then
    tools="${KUBEXM_TOOL_CHECKS} ${tools}"
  fi

  local arch
  arch="$(utils::get_arch)"

  local tool
  for tool in ${tools}; do
    # Special case for jq on non-amd64: check if xmjq can substitute
    if [[ "${tool}" == "jq" && "${arch}" != "amd64" ]]; then
      if command -v jq >/dev/null 2>&1; then
        continue
      fi
      if [[ -x "${KUBEXM_ROOT}/bin/xmjq" ]] || command -v xmjq >/dev/null 2>&1; then
        continue
      fi
      return 1
    fi

    # Check if tool exists in PATH
    if command -v "${tool}" >/dev/null 2>&1; then
      continue
    fi

    # Check if tool symlink exists in bin directory
    if [[ -x "${KUBEXM_ROOT}/bin/${tool}" ]]; then
      continue
    fi

    # Check if tool is packaged
    local packaged_tool="${KUBEXM_ROOT}/packages/tools/common/${arch}/${tool}"
    if [[ -f "${packaged_tool}" ]]; then
      continue
    fi

    # Tool not found
    return 1
  done

  return 0
}

step::check.tools.binary::run() {
  local tools="jq yq xmjq xmyq xmparser xmrender"
  if [[ -n "${KUBEXM_TOOL_CHECKS:-}" ]]; then
    tools="${KUBEXM_TOOL_CHECKS} ${tools}"
  fi

  local arch
  arch="$(utils::get_arch)"

  local missing=()
  local tool
  for tool in ${tools}; do
    if [[ "${tool}" == "jq" && "${arch}" != "amd64" ]]; then
      if command -v jq >/dev/null 2>&1; then
        continue
      fi
      if command -v xmjq >/dev/null 2>&1 || [[ -x "${KUBEXM_ROOT}/bin/xmjq" ]]; then
        mkdir -p "${KUBEXM_ROOT}/bin" || return 1
        ln -sf "${KUBEXM_ROOT}/bin/xmjq" "${KUBEXM_ROOT}/bin/jq"
        continue
      fi
    fi
    if command -v "${tool}" >/dev/null 2>&1; then
      continue
    fi
    if [[ -x "${KUBEXM_ROOT}/bin/${tool}" ]]; then
      continue
    fi
    local packaged_tool="${KUBEXM_ROOT}/packages/tools/common/${arch}/${tool}"
    if [[ -f "${packaged_tool}" ]]; then
      chmod +x "${packaged_tool}" || true
      mkdir -p "${KUBEXM_ROOT}/bin" || return 1
      ln -sf "${packaged_tool}" "${KUBEXM_ROOT}/bin/${tool}"
      continue
    fi
    missing+=("${tool}")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "missing required tools: ${missing[*]}" >&2
    return 2
  fi
}

step::check.tools.binary::rollback() { return 0; }

step::check.tools.binary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
