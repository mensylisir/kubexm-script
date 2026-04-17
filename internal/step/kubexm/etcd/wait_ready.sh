#!/usr/bin/env bash
set -euo pipefail

step::etcd.wait.ready::_cert_dir() {
  local etcd_type
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo kubeadm)
  if [[ "${etcd_type}" == "kubexm" ]]; then
    printf '%s' "/etc/etcd/ssl"
  else
    printf '%s' "/etc/kubernetes/pki/etcd"
  fi
}

step::etcd.wait.ready::_cert_args() {
  local cert_dir="$1"
  if runner::remote_exec "test -f ${cert_dir}/healthcheck-client.crt" >/dev/null 2>&1; then
    printf '%s' "--cacert ${cert_dir}/ca.crt --cert ${cert_dir}/healthcheck-client.crt --key ${cert_dir}/healthcheck-client.key"
    return 0
  fi
  if runner::remote_exec "test -f ${cert_dir}/server.crt" >/dev/null 2>&1; then
    printf '%s' "--cacert ${cert_dir}/ca.crt --cert ${cert_dir}/server.crt --key ${cert_dir}/server.key"
    return 0
  fi
  return 1
}

step::etcd.wait.ready::check() {
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"

  local cert_dir cert_args
  cert_dir=$(step::etcd.wait.ready::_cert_dir)

  if ! step::check::remote_service_running "${KUBEXM_HOST}" "etcd" 2>/dev/null; then
    return 1
  fi

  cert_args=$(step::etcd.wait.ready::_cert_args "${cert_dir}" || true)
  if [[ -z "${cert_args}" ]]; then
    return 1
  fi

  if runner::remote_exec "ETCDCTL_API=3 etcdctl endpoint health --cluster ${cert_args}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

step::etcd.wait.ready::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local max_attempts
  max_attempts=${KUBEXM_ETCD_WAIT_RETRIES:-24}
  if ! [[ "${max_attempts}" =~ ^[0-9]+$ ]] || [[ "${max_attempts}" -lt 1 ]]; then
    log::warn "Invalid KUBEXM_ETCD_WAIT_RETRIES='${max_attempts}', using default 24"
    max_attempts=24
  fi
  local attempt=1

  while [[ ${attempt} -le ${max_attempts} ]]; do
    local cert_dir cert_args
    cert_dir=$(step::etcd.wait.ready::_cert_dir)
    cert_args=$(step::etcd.wait.ready::_cert_args "${cert_dir}" || true)

    if [[ -z "${cert_args}" ]]; then
      log::warn "Etcd health check cannot run on ${KUBEXM_HOST} (missing certs in ${cert_dir})"
      return 1
    fi

    if runner::remote_exec "ETCDCTL_API=3 etcdctl endpoint health --cluster ${cert_args}" >/dev/null 2>&1; then
      log::info "Etcd is healthy on ${KUBEXM_HOST}"
      return 0
    fi

    log::info "Waiting for etcd health on ${KUBEXM_HOST}... (${attempt}/${max_attempts})"
    attempt=$((attempt + 1))
    sleep 5
  done

  log::error "Etcd health check failed on ${KUBEXM_HOST}"
  return 1
}

step::etcd.wait.ready::rollback() { return 0; }

step::etcd.wait.ready::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd
}
