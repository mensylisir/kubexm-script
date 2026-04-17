#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.distribute.pki.k8s.copy::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/pki/ca.crt"
}

step::kubernetes.distribute.pki.k8s.copy::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local pki_dir is_control_plane
  pki_dir="$(context::get "kubernetes_pki_dir" || true)"
  is_control_plane="$(context::get "kubernetes_pki_is_control_plane" || true)"

  runner::remote_exec "mkdir -p /etc/kubernetes/pki"

  local file
  for file in "${pki_dir}"/*; do
    [[ -f "${file}" ]] || continue
    if [[ "${is_control_plane}" != "true" ]]; then
      case "$(basename "${file}")" in
        ca.key|ca-key.pem) continue ;;
      esac
    fi
    runner::remote_copy_file "${file}" "/etc/kubernetes/pki/$(basename "${file}")"
  done
}

step::kubernetes.distribute.pki.k8s.copy::rollback() { return 0; }

step::kubernetes.distribute.pki.k8s.copy::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
