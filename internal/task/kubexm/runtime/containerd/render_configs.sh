#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.containerd.render.configs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/containerd/config.toml"
}

step::cluster.install.runtime.containerd.render.configs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local local_cfg
  local_cfg="$(context::get "runtime_containerd_local_cfg" || true)"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  if [[ -f "${local_cfg}" ]]; then
    runner::remote_exec "mkdir -p /etc/containerd"
    runner::remote_copy_file "${local_cfg}" "/etc/containerd/config.toml"
  else
    template::render "${KUBEXM_ROOT}/templates/runtime/containerd/config.toml.tmpl" "${tmp_dir}/config.toml"
    runner::remote_exec "mkdir -p /etc/containerd"
    runner::remote_copy_file "${tmp_dir}/config.toml" "/etc/containerd/config.toml"
  fi

  template::render "${KUBEXM_ROOT}/templates/runtime/containerd/containerd.service.tmpl" "${tmp_dir}/containerd.service"
  runner::remote_copy_file "${tmp_dir}/containerd.service" "/etc/systemd/system/containerd.service"

  cat > "${tmp_dir}/crictl.json" <<EOF
{"RuntimeEndpoint":"unix:///run/containerd/containerd.sock","ImageEndpoint":"unix:///run/containerd/containerd.sock","Timeout":10,"Debug":false}
EOF
  template::render "${KUBEXM_ROOT}/templates/runtime/crictl/crictl.yaml.tmpl" "${tmp_dir}/crictl.yaml" "" "${tmp_dir}/crictl.json"
  runner::remote_copy_file "${tmp_dir}/crictl.yaml" "/etc/crictl.yaml"
}

step::cluster.install.runtime.containerd.render.configs::rollback() { return 0; }

step::cluster.install.runtime.containerd.render.configs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
