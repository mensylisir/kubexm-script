#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.docker.render.configs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/docker/daemon.json"
}

step::cluster.install.runtime.docker.render.configs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local local_docker_cfg
  local_docker_cfg="$(context::get "runtime_docker_local_cfg" || true)"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  if [[ -f "${local_docker_cfg}" ]]; then
    runner::remote_exec "mkdir -p /etc/docker"
    runner::remote_copy_file "${local_docker_cfg}" "/etc/docker/daemon.json"
  else
    template::render "${KUBEXM_ROOT}/templates/runtime/docker/daemon.json.tmpl" "${tmp_dir}/daemon.json"
    runner::remote_exec "mkdir -p /etc/docker"
    runner::remote_copy_file "${tmp_dir}/daemon.json" "/etc/docker/daemon.json"
  fi

  template::render "${KUBEXM_ROOT}/templates/runtime/docker/docker.service.tmpl" "${tmp_dir}/docker.service"
  runner::remote_copy_file "${tmp_dir}/docker.service" "/etc/systemd/system/docker.service"

  local pause_image="registry.k8s.io/pause:3.10"
  cat > "${tmp_dir}/cri-dockerd.json" <<EOF
{"PauseImage":"${pause_image}"}
EOF
  template::render "${KUBEXM_ROOT}/templates/runtime/cri-dockerd/cri-dockerd.service.tmpl" "${tmp_dir}/cri-dockerd.service" "" "${tmp_dir}/cri-dockerd.json"
  runner::remote_copy_file "${tmp_dir}/cri-dockerd.service" "/etc/systemd/system/cri-dockerd.service"

  cat > "${tmp_dir}/crictl.json" <<EOF
{"RuntimeEndpoint":"unix:///var/run/cri-dockerd.sock","ImageEndpoint":"unix:///var/run/cri-dockerd.sock","Timeout":10,"Debug":false}
EOF
  template::render "${KUBEXM_ROOT}/templates/runtime/crictl/crictl.yaml.tmpl" "${tmp_dir}/crictl.yaml" "" "${tmp_dir}/crictl.json"
  runner::remote_copy_file "${tmp_dir}/crictl.yaml" "/etc/crictl.yaml"
}

step::cluster.install.runtime.docker.render.configs::rollback() { return 0; }

step::cluster.install.runtime.docker.render.configs::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
