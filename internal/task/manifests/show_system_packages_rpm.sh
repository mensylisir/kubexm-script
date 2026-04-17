#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.system.packages.rpm::check() { return 1; }

step::manifests.show.system.packages.rpm::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  echo "  CentOS/RHEL/Rocky/Alma/Kylin/UOS (默认包):"
  local rpm_packages
  rpm_packages=($(context::get "manifests_system_packages_rpm" || true))
  local pkg
  for pkg in "${rpm_packages[@]}"; do
    echo "    - $(defaults::get_rpm_package_name "$pkg")"
  done
  echo
}

step::manifests.show.system.packages.rpm::rollback() { return 0; }

step::manifests.show.system.packages.rpm::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
