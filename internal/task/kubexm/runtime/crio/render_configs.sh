#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.crio.render.configs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/crio/crio.conf"
}

step::cluster.install.runtime.crio.render.configs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/utils/template.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  local pause_image="registry.k8s.io/pause:3.10"
  cat > "${tmp_dir}/crio.json" <<EOF
{"PauseImage":"${pause_image}"}
EOF
  template::render "${KUBEXM_ROOT}/templates/runtime/cri-o/cri-o.conf.tmpl" "${tmp_dir}/crio.conf" "" "${tmp_dir}/crio.json"
  template::render "${KUBEXM_ROOT}/templates/runtime/cri-o/cri-o.service.tmpl" "${tmp_dir}/crio.service"
  template::render "${KUBEXM_ROOT}/templates/runtime/cri-o/policy.json.tmpl" "${tmp_dir}/policy.json"

  runner::remote_exec "mkdir -p /etc/crio /etc/containers"
  runner::remote_copy_file "${tmp_dir}/crio.conf" "/etc/crio/crio.conf"
  runner::remote_copy_file "${tmp_dir}/crio.service" "/etc/systemd/system/crio.service"
  runner::remote_copy_file "${tmp_dir}/policy.json" "/etc/containers/policy.json"

  cat > "${tmp_dir}/crictl.json" <<EOF
{"RuntimeEndpoint":"unix:///var/run/crio/crio.sock","ImageEndpoint":"unix:///var/run/crio/crio.sock","Timeout":10,"Debug":false}
EOF
  template::render "${KUBEXM_ROOT}/templates/runtime/crictl/crictl.yaml.tmpl" "${tmp_dir}/crictl.yaml" "" "${tmp_dir}/crictl.json"
  runner::remote_copy_file "${tmp_dir}/crictl.yaml" "/etc/crictl.yaml"
}

step::cluster.install.runtime.crio.render.configs::rollback() { return 0; }

step::cluster.install.runtime.crio.render.configs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
