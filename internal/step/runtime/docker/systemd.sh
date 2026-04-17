#!/usr/bin/env bash
set -euo pipefail

step::runtime.cri.dockerd.systemd::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_service_running "${KUBEXM_HOST}" "cri-dockerd" 2>/dev/null; then
    return 0  # already running, skip
  fi
  return 1  # need to start
}

step::runtime.cri.dockerd.systemd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Setting up cri-dockerd systemd service on ${KUBEXM_HOST}..."

  # Create systemd service file for cri-dockerd
  runner::remote_exec "cat > /etc/systemd/system/cri-dockerd.service << 'EOF'
[Unit]
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cri-dockerd --network-plugin=cri --pod-infra-container-image=registry.k8s.io/pause:3.9
Restart=always
RestartSec=5
Delegate=yes
KillMode=process

[Install]
WantedBy=multi-user.target
EOF"

  runner::remote_exec "systemctl daemon-reload && systemctl enable cri-dockerd && systemctl start cri-dockerd"
  log::info "cri-dockerd systemd service started on ${KUBEXM_HOST}"
}

step::runtime.cri.dockerd.systemd::rollback() { return 0; }

step::runtime.cri.dockerd.systemd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}