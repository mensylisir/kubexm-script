#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.helm::check() { return 1; }

step::manifests.show.helm::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/helm_manager.sh"
  source "${KUBEXM_ROOT}/internal/utils/image_manager.sh"
  source "${KUBEXM_ROOT}/internal/utils/helm_bom.sh"

  local enabled_addons
  enabled_addons=$(image_manager::get_enabled_addons)

  if [[ -n "$enabled_addons" ]]; then
    echo "=== Helm包 ==="
    while IFS= read -r item; do
      [[ -z "$item" ]] && continue
      IFS=':' read -r a_name a_conf a_rel a_path <<< "$item"
      local info
      info=$(utils::helm::bom::get_chart_info "$a_name")
      if [[ -n "$info" ]]; then
        local url
        url=$(echo "$info" | cut -d: -f2-)
        echo "  $a_name: $url"
      fi
    done <<< "$enabled_addons"
    echo
  fi
}

step::manifests.show.helm::rollback() { return 0; }

step::manifests.show.helm::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
