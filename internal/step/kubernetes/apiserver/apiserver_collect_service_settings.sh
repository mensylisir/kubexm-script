#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.apiserver.collect.service.settings::check() { return 1; }

step::kubernetes.apiserver.collect.service.settings::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_domain service_cidr
  cluster_domain=$(config::get_cluster_domain)
  service_cidr=$(config::get_service_cidr)
  local service_node_port_range
  service_node_port_range=$(config::get "spec.kubernetes.apiserver.service_node_port_range" "30000-32767")

  local service_account_issuer
  service_account_issuer=$(config::get "spec.kubernetes.apiserver.service_account_issuer" "")
  if [[ -z "${service_account_issuer}" ]]; then
    service_account_issuer="https://kubernetes.default.svc.${cluster_domain}"
  fi

  context::set "kubernetes_apiserver_service_cidr" "${service_cidr}"
  context::set "kubernetes_apiserver_service_node_port_range" "${service_node_port_range}"
  context::set "kubernetes_apiserver_service_account_issuer" "${service_account_issuer}"
}

step::kubernetes.apiserver.collect.service.settings::rollback() { return 0; }

step::kubernetes.apiserver.collect.service.settings::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
