#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.check.version::check() { return 1; }

step::cluster.upgrade.check.version::run() {
  local ctx="$1"
  shift
  local target_version=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --to-version=*) target_version="${arg#*=}" ;;
    esac
  done
  if [[ -z "${target_version}" ]]; then
    echo "missing required --to-version for upgrade cluster" >&2
    return 2
  fi
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local current_version
  current_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | awk '{print $3}' | cut -d'v' -f2 || echo "")
  if [[ -z "${current_version}" ]]; then
    log::error "Failed to get current cluster version"
    return 1
  fi

  log::info "Current version: ${current_version}"
  log::info "Target version: ${target_version}"

  local current_version_norm="${current_version#v}"
  local target_version_norm="${target_version#v}"
  local current_major current_minor target_major target_minor
  current_major=$(echo "${current_version_norm}" | cut -d'.' -f1)
  current_minor=$(echo "${current_version_norm}" | cut -d'.' -f2)
  target_major=$(echo "${target_version_norm}" | cut -d'.' -f1)
  target_minor=$(echo "${target_version_norm}" | cut -d'.' -f2)

  # Block major version upgrades
  if [[ ${target_major} -gt ${current_major} ]]; then
    log::error "Major version upgrade from ${current_major}.x to ${target_major}.x is not supported!"
    log::error "Please migrate to a new cluster instead."
    return 1
  fi

  # Block downgrades
  if [[ ${target_major} -lt ${current_major} ]] || \
     ([[ ${target_major} -eq ${current_major} ]] && [[ ${target_minor} -lt ${current_minor} ]]); then
    log::error "Downgrade from ${current_version} to ${target_version} is not allowed!"
    return 1
  fi

  # Block multi-minor version skips (Kubernetes only supports n -> n+1)
  if [[ ${target_major} -eq ${current_major} ]] && [[ $((target_minor - current_minor)) -gt 1 ]]; then
    log::error "Skipping minor versions is not supported!"
    log::error "Current: ${current_version}, Target: ${target_version}"
    log::error "Please upgrade one minor version at a time:"
    log::error "  ${current_version} -> $(echo "${current_version}" | awk -F. '{print $1"."$2+1".0"}')"
    return 1
  fi

  # Warn about same version upgrade
  if [[ ${target_major} -eq ${current_major} ]] && [[ ${target_minor} -eq ${current_minor} ]]; then
    log::warn "Target version ${target_version} is the same as current version ${current_version}"
    log::warn "This will re-apply configurations but won't change the version"
  fi
}

step::cluster.upgrade.check.version::rollback() { return 0; }

step::cluster.upgrade.check.version::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
