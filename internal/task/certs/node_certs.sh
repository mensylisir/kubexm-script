#!/usr/bin/env bash
set -euo pipefail

# 配置依赖：统一在文件顶部加载
source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"
source "${KUBEXM_ROOT}/internal/utils/pki.sh"

node_certs::prepare() {
  local cluster_name="$1"
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  local cluster_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/${cluster_name}/certs"
  local cluster_domain api_vip service_cidr
  cluster_domain=$(config::get_cluster_domain)
  api_vip=$(config::get_apiserver_address)
  service_cidr=$(config::get_service_cidr)

  local k8s_svc_ip
  k8s_svc_ip=$(echo "${service_cidr}" | sed 's/\.[0-9]*\/.*/.1/')

  local control_plane_nodes etcd_nodes etcd_type all_etcd_ips
  control_plane_nodes=$(config::get_role_members 'control-plane')
  etcd_nodes=$(config::get_role_members 'etcd')
  etcd_type=$(config::get_etcd_type)
  all_etcd_ips=""

  local node
  for node in ${etcd_nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ -n "${node_ip}" ]]; then
      all_etcd_ips="${all_etcd_ips},${node_ip}"
    fi
  done
  all_etcd_ips="${all_etcd_ips#,}"

  local first_master
  first_master=$(echo "${control_plane_nodes}" | awk '{print $1}')
  local shared_ca_dir="${cluster_dir}/${first_master}/certs"

  export NC_CLUSTER_DIR="${cluster_dir}"
  export NC_CLUSTER_DOMAIN="${cluster_domain}"
  export NC_API_VIP="${api_vip}"
  export NC_SERVICE_CIDR="${service_cidr}"
  export NC_K8S_SVC_IP="${k8s_svc_ip}"
  export NC_CONTROL_PLANE_NODES="${control_plane_nodes}"
  export NC_ETCD_NODES="${etcd_nodes}"
  export NC_ETCD_TYPE="${etcd_type}"
  export NC_ALL_ETCD_IPS="${all_etcd_ips}"
  export NC_FIRST_MASTER="${first_master}"
  export NC_SHARED_CA_DIR="${shared_ca_dir}"
}

node_certs::resolve_node_name() {
  local node_name=""
  local node
  for node in $(config::get_all_host_names); do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  if [[ -z "${node_name}" ]]; then
    node_name="${KUBEXM_HOST}"
  fi
  printf '%s' "${node_name}"
}
