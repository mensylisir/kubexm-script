#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.worker.render::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local local_config
  local_config="$(context::get "kubeadm_join_worker_local_config" || true)"
  if [[ -n "${local_config}" && -f "${local_config}" ]]; then
    return 0
  fi
  return 1
}

step::kubeadm.join.worker.render::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local cluster_name join_token ca_hash apiserver_endpoint cri_socket node_name node_ip local_config template_file
  cluster_name="$(context::get "kubeadm_join_worker_cluster_name" || true)"
  join_token="$(context::get "kubeadm_join_worker_join_token" || true)"
  ca_hash="$(context::get "kubeadm_join_worker_ca_hash" || true)"
  apiserver_endpoint="$(context::get "kubeadm_join_worker_apiserver_endpoint" || true)"
  cri_socket="$(context::get "kubeadm_join_worker_cri_socket" || true)"
  node_name="$(context::get "kubeadm_join_worker_node_name" || true)"
  node_ip="$(context::get "kubeadm_join_worker_node_ip" || true)"
  local_config="$(context::get "kubeadm_join_worker_local_config" || true)"
  template_file="$(context::get "kubeadm_join_worker_template_file" || true)"

  if [[ -f "${template_file}" ]]; then
    template::render_with_vars \
      "${template_file}" \
      "${local_config}" \
      "CLUSTER_NAME=${cluster_name}" \
      "APISERVER_ENDPOINT=${apiserver_endpoint}" \
      "BOOTSTRAP_TOKEN=${join_token}" \
      "TLS_BOOTSTRAP_TOKEN=${join_token}" \
      "UNSAFE_SKIP_CA_VERIFICATION=true" \
      "CRI_SOCKET=${cri_socket}" \
      "NODE_NAME=${node_name}" \
      "NODE_IP=${node_ip}"
  else
    cat > "${local_config}" <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "${apiserver_endpoint}"
    token: "${join_token}"
    caCertHashes:
      - "sha256:${ca_hash}"
nodeRegistration:
  name: "${node_name}"
  criSocket: "${cri_socket}"
EOF
  fi
}

step::kubeadm.join.worker.render::rollback() { return 0; }

step::kubeadm.join.worker.render::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
