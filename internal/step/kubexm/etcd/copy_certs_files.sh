#!/usr/bin/env bash
set -euo pipefail

step::etcd.copy.certs.files::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/etcd/ssl/ca.crt"
}

step::etcd.copy.certs.files::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local cert_dir
  cert_dir="$(context::get "etcd_certs_dir" || true)"

  if [[ -f "${cert_dir}/ca.crt" ]]; then
    runner::remote_copy_file "${cert_dir}/ca.crt" "/etc/etcd/ssl/ca.crt"
  fi
  if [[ -f "${cert_dir}/server.crt" ]]; then
    runner::remote_copy_file "${cert_dir}/server.crt" "/etc/etcd/ssl/server.crt"
  fi
  if [[ -f "${cert_dir}/server.key" ]]; then
    runner::remote_copy_file "${cert_dir}/server.key" "/etc/etcd/ssl/server.key"
  elif [[ -f "${cert_dir}/server-key.pem" ]]; then
    runner::remote_copy_file "${cert_dir}/server-key.pem" "/etc/etcd/ssl/server.key"
  fi
  if [[ -f "${cert_dir}/peer.crt" ]]; then
    runner::remote_copy_file "${cert_dir}/peer.crt" "/etc/etcd/ssl/peer.crt"
  fi
  if [[ -f "${cert_dir}/peer.key" ]]; then
    runner::remote_copy_file "${cert_dir}/peer.key" "/etc/etcd/ssl/peer.key"
  elif [[ -f "${cert_dir}/peer-key.pem" ]]; then
    runner::remote_copy_file "${cert_dir}/peer-key.pem" "/etc/etcd/ssl/peer.key"
  fi
  if [[ -f "${cert_dir}/healthcheck-client.crt" ]]; then
    runner::remote_copy_file "${cert_dir}/healthcheck-client.crt" "/etc/etcd/ssl/healthcheck-client.crt"
  fi
  if [[ -f "${cert_dir}/healthcheck-client.key" ]]; then
    runner::remote_copy_file "${cert_dir}/healthcheck-client.key" "/etc/etcd/ssl/healthcheck-client.key"
  elif [[ -f "${cert_dir}/healthcheck-client-key.pem" ]]; then
    runner::remote_copy_file "${cert_dir}/healthcheck-client-key.pem" "/etc/etcd/ssl/healthcheck-client.key"
  fi
}

step::etcd.copy.certs.files::rollback() { return 0; }

step::etcd.copy.certs.files::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
