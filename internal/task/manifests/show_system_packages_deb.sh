#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.system.packages.deb::check() { return 1; }

step::manifests.show.system.packages.deb::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  echo "  Ubuntu/Debian (默认包):"
  local deb_packages
  deb_packages=($(context::get "manifests_system_packages_deb" || true))
  local pkg
  for pkg in "${deb_packages[@]}"; do
    echo "    - $(defaults::get_deb_package_name "$pkg")"
  done
  echo
}

step::manifests.show.system.packages.deb::rollback() { return 0; }

step::manifests.show.system.packages.deb::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
