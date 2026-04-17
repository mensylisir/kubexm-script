#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.apiserver.render.service::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local service_dir
  service_dir="$(context::get "kubernetes_apiserver_service_dir" || true)"
  if [[ -n "${service_dir}" && -f "${service_dir}/kube-apiserver.service" ]]; then
    return 0
  fi
  return 1
}

step::kubernetes.apiserver.render.service::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local cluster_name node_name node_ip etcd_servers service_cidr service_node_port_range
  local service_account_issuer audit_log_maxage audit_log_maxbackup audit_log_maxsize service_dir

  cluster_name="$(context::get "kubernetes_apiserver_cluster_name" || true)"
  node_name="$(context::get "kubernetes_apiserver_node_name" || true)"
  node_ip="$(context::get "kubernetes_apiserver_node_ip" || true)"
  etcd_servers="$(context::get "kubernetes_apiserver_etcd_servers" || true)"
  service_cidr="$(context::get "kubernetes_apiserver_service_cidr" || true)"
  service_node_port_range="$(context::get "kubernetes_apiserver_service_node_port_range" || true)"
  service_account_issuer="$(context::get "kubernetes_apiserver_service_account_issuer" || true)"
  audit_log_maxage="$(context::get "kubernetes_apiserver_audit_log_maxage" || true)"
  audit_log_maxbackup="$(context::get "kubernetes_apiserver_audit_log_maxbackup" || true)"
  audit_log_maxsize="$(context::get "kubernetes_apiserver_audit_log_maxsize" || true)"
  service_dir="$(context::get "kubernetes_apiserver_service_dir" || true)"

  template::render_with_vars \
    "${KUBEXM_ROOT}/templates/kubernetes/kube-apiserver/kube-apiserver.service.tmpl" \
    "${service_dir}/kube-apiserver.service" \
    "CLUSTER_NAME=${cluster_name}" \
    "NODE_NAME=${node_name}" \
    "NODE_IP=${node_ip}" \
    "ETCD_SERVERS=${etcd_servers}" \
    "SERVICE_CIDR=${service_cidr}" \
    "SERVICE_NODE_PORT_RANGE=${service_node_port_range}" \
    "SERVICE_ACCOUNT_ISSUER=${service_account_issuer}" \
    "AUDIT_LOG_MAXAGE=${audit_log_maxage}" \
    "AUDIT_LOG_MAXBACKUP=${audit_log_maxbackup}" \
    "AUDIT_LOG_MAXSIZE=${audit_log_maxsize}"
}

step::kubernetes.apiserver.render.service::rollback() { return 0; }

step::kubernetes.apiserver.render.service::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
