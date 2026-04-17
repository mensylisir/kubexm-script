#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Kubeadm Config Helpers
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KUBEXM_ROOT="${KUBEXM_ROOT:-$KUBEXM_SCRIPT_ROOT}"

source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/template.sh"

kubeadm::generate_init_config() {
  local output_file="$1"
  local node_name="${2:-}"

  log::info "Generating kubeadm configuration from template..."

  local service_cidr
  service_cidr=$(config::get_service_cidr)
  local pod_cidr
  pod_cidr=$(config::get_pod_cidr)
  local cluster_domain
  cluster_domain=$(config::get_cluster_domain)
  local k8s_version
  k8s_version=$(config::get_kubernetes_version)
  local cluster_name="${KUBEXM_CLUSTER_NAME:-default}"
  local cluster_dns_ip
  cluster_dns_ip=$(config::get "spec.kubernetes.cluster_dns_ip" "$(defaults::get_cluster_dns_ip)" 2>/dev/null || defaults::get_cluster_dns_ip)
  local image_repository
  image_repository=$(config::get_image_registry)
  local coredns_version
  coredns_version=$(config::get "spec.kubernetes.coredns.version" "$(defaults::get_coredns_version)" 2>/dev/null || defaults::get_coredns_version)

  local effective_node_name="${node_name}"
  if [[ -z "${effective_node_name}" ]]; then
    effective_node_name=$(config::get_role_members "control-plane" | awk '{print $1}')
  fi

  local node_ip
  node_ip=$(config::get_host_param "${effective_node_name}" "address")
  if [[ -z "${node_ip}" ]]; then
    node_ip="$(config::get_apiserver_address 2>/dev/null || true)"
  fi
  if [[ -z "${node_ip}" ]]; then
    local local_ips
    local_ips="$(hostname -I 2>/dev/null || true)"
    node_ip="$(awk '{print $1}' <<< "${local_ips}")"
  fi
  if [[ -z "${node_ip}" ]]; then
    log::error "Failed to resolve node IP for kubeadm init config"
    return 1
  fi

  local control_plane_endpoint
  control_plane_endpoint=$(config::get_loadbalancer_vip 2>/dev/null || true)
  if [[ -z "${control_plane_endpoint}" ]]; then
    control_plane_endpoint=$(config::get_apiserver_address 2>/dev/null || true)
  fi
  if [[ -z "${control_plane_endpoint}" ]]; then
    control_plane_endpoint="${node_ip}"
  fi
  control_plane_endpoint="${control_plane_endpoint%%:*}"

  local service_node_port_range
  service_node_port_range=$(config::get "spec.kubernetes.apiserver.service_node_port_range" "30000-32767")
  local node_cidr_mask_size
  node_cidr_mask_size=$(config::get "spec.kubernetes.controller_manager.node_cidr_mask_size" "24")
  local cluster_signing_duration
  cluster_signing_duration=$(config::get "spec.kubernetes.controller_manager.cluster_signing_duration" "87600h")
  local max_pods
  max_pods=$(config::get "spec.kubernetes.kubelet.max_pods" "110")
  local kube_proxy_mode
  kube_proxy_mode=$(config::get_kube_proxy_mode)

  local etcd_config_block=""
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo "kubeadm")
  if [[ "${etcd_type}" == "exists" || "${etcd_type}" == "kubexm" ]]; then
    local etcd_servers
    etcd_servers=$(config::get_etcd_external_endpoints)
    if [[ -n "${etcd_servers}" ]]; then
      local etcd_endpoints_yaml=""
      local endpoint
      IFS=',' read -r -a _etcd_endpoints <<< "${etcd_servers}"
      for endpoint in "${_etcd_endpoints[@]}"; do
        endpoint="$(echo "${endpoint}" | xargs)"
        [[ -n "${endpoint}" ]] && etcd_endpoints_yaml+="      - ${endpoint}"$'\n'
      done
      if [[ -n "${etcd_endpoints_yaml}" ]]; then
        etcd_config_block="etcd:\n  external:\n    endpoints:\n${etcd_endpoints_yaml%$'\n'}"
      fi
    fi
  fi

  local runtime_type
  runtime_type=$(config::get_runtime_type 2>/dev/null || echo "containerd")
  local cri_socket
  case "${runtime_type}" in
    containerd) cri_socket="unix:///run/containerd/containerd.sock" ;;
    docker)     cri_socket="unix:///var/run/cri-dockerd.sock" ;;
    crio)       cri_socket="unix:///var/run/crio/crio.sock" ;;
    *)          cri_socket="unix:///run/containerd/containerd.sock" ;;
  esac

  local audit_log_maxage
  audit_log_maxage=$(config::get "spec.kubernetes.apiserver.audit.log_maxage" "30" 2>/dev/null || echo "30")
  local audit_log_maxbackup
  audit_log_maxbackup=$(config::get "spec.kubernetes.apiserver.audit.log_maxbackup" "10" 2>/dev/null || echo "10")
  local audit_log_maxsize
  audit_log_maxsize=$(config::get "spec.kubernetes.apiserver.audit.log_maxsize" "100" 2>/dev/null || echo "100")

  local template_file="${KUBEXM_ROOT}/templates/kubernetes/kubeadm/init-master.yaml.tmpl"
  template::render_with_vars \
    "${template_file}" \
    "${output_file}" \
    "CLUSTER_NAME=${cluster_name}" \
    "NODE_NAME=${effective_node_name}" \
    "NODE_IP=${node_ip}" \
    "KUBERNETES_VERSION=${k8s_version}" \
    "CONTROL_PLANE_ENDPOINT=${control_plane_endpoint}" \
    "IMAGE_REPOSITORY=${image_repository}" \
    "CLUSTER_DOMAIN=${cluster_domain}" \
    "SERVICE_CIDR=${service_cidr}" \
    "POD_CIDR=${pod_cidr}" \
    "SERVICE_NODE_PORT_RANGE=${service_node_port_range}" \
    "CERT_SANS=" \
    "NODE_CIDR_MASK_SIZE=${node_cidr_mask_size}" \
    "CLUSTER_SIGNING_DURATION=${cluster_signing_duration}" \
    "ETCD_CONFIG_BLOCK=${etcd_config_block}" \
    "COREDNS_VERSION=${coredns_version}" \
    "CLUSTER_DNS_IP=${cluster_dns_ip}" \
    "CRI_SOCKET=${cri_socket}" \
    "MAX_PODS=${max_pods}" \
    "KUBE_PROXY_MODE=${kube_proxy_mode}" \
    "AUDIT_LOG_MAXAGE=${audit_log_maxage}" \
    "AUDIT_LOG_MAXBACKUP=${audit_log_maxbackup}" \
    "AUDIT_LOG_MAXSIZE=${audit_log_maxsize}"

  log::success "Kubeadm config generated: ${output_file}"
}

kubeadm::generate_audit_policy() {
  local output_dir="$1"

  log::info "Generating audit policy..."

  local template_file="${KUBEXM_ROOT}/templates/kubernetes/audit/audit-policy.yaml.tmpl"
  local policy_file="${output_dir}/audit-policy.yaml"
  local cluster_name="${KUBEXM_CLUSTER_NAME:-default}"

  if [[ ! -f "${template_file}" ]]; then
    log::warn "Audit policy template not found: ${template_file}"
    return 0
  fi

  template::render_with_vars \
    "${template_file}" \
    "${policy_file}" \
    "CLUSTER_NAME=${cluster_name}"

  log::success "Audit policy generated: ${policy_file}"
}

kubeadm::generate_encryption_config() {
  local output_dir="$1"

  log::info "Generating encryption at rest config..."

  local config_file="${output_dir}/encryption-config.yaml"
  local cluster_name="${KUBEXM_CLUSTER_NAME:-default}"

  # 使用 AES-CBC 加密（Kubernetes 原生支持）
  # 生成 32 字节随机 key 并 base64 编码
  local encryption_key
  encryption_key=$(head -c 32 /dev/urandom | base64 2>/dev/null || openssl rand -base64 32 2>/dev/null || echo "cmFuZG9tLWtleS1nZW5lcmF0ZWQtYnkta3ViZXht")

  cat > "${config_file}" <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${encryption_key}
      - identity: {}
EOF

  chmod 600 "${config_file}"
  log::success "Encryption config generated: ${config_file}"
  log::warn "IMPORTANT: Store this key securely. It is required for etcd backup/restore."
}

kubeadm::generate_external_etcd_config() {
  local output_file="$1"

  log::info "Generating kubeadm config for external etcd..."

  local etcd_endpoints=()
  local external_endpoints_csv
  external_endpoints_csv=$(config::get_etcd_external_endpoints)
  if [[ -n "${external_endpoints_csv}" ]]; then
    IFS=',' read -r -a etcd_endpoints <<< "${external_endpoints_csv}"
  else
    local etcd_nodes
    etcd_nodes=$(config::get_role_members "etcd")
    for node in ${etcd_nodes}; do
      local node_ip
      node_ip=$(config::get_host_param "${node}" "address")
      [[ -n "${node_ip}" ]] && etcd_endpoints+=("https://${node_ip}:2379")
    done
  fi

  if [[ ${#etcd_endpoints[@]} -eq 0 ]]; then
    log::error "No external etcd endpoints found (spec.etcd.external_endpoints or etcd role nodes)"
    return 1
  fi

  local etcd_endpoints_yaml=""
  local endpoint
  for endpoint in "${etcd_endpoints[@]}"; do
    endpoint="$(echo "${endpoint}" | xargs)"
    [[ -z "${endpoint}" ]] && continue
    etcd_endpoints_yaml+="      - ${endpoint}"$'\n'
  done

  local k8s_version
  k8s_version=$(config::get_kubernetes_version)
  local pod_cidr
  pod_cidr=$(config::get_pod_cidr)
  local service_cidr
  service_cidr=$(config::get_service_cidr)
  local cluster_name="${KUBEXM_CLUSTER_NAME:-kubernetes}"
  local control_plane_endpoint
  control_plane_endpoint=$(config::get_vip_address)
  if [[ -z "${control_plane_endpoint}" ]]; then
    local first_master
    first_master=$(config::get_role_members "control-plane" | awk '{print $1}')
    control_plane_endpoint=$(config::get_host_param "${first_master}" "address")
  fi
  if [[ -z "${control_plane_endpoint}" ]]; then
    log::error "Failed to resolve controlPlaneEndpoint for external etcd mode"
    return 1
  fi

  if [[ "${control_plane_endpoint}" != *:* ]]; then
    control_plane_endpoint="${control_plane_endpoint}:6443"
  fi

  printf '%s\n' \
"apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cgroup-driver: systemd
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: ${k8s_version}
controlPlaneEndpoint: \"${control_plane_endpoint}\"
etcd:
  external:
    endpoints:
${etcd_endpoints_yaml%$'\n'}
    caFile: /etc/kubernetes/pki/etcd/ca.crt
    certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
    keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
  podSubnet: ${pod_cidr}
  serviceSubnet: ${service_cidr}
clusterName: ${cluster_name}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: KubeletConfiguration
cgroupDriver: systemd" > "${output_file}"

  log::success "Kubeadm config generated: ${output_file}"
}
