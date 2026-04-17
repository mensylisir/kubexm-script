#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Config Loader (Multi-cluster Concurrent Support)
# ==============================================================================
# 设计规范: 变量隔离 — 每个集群的配置状态通过 cluster-scoped context 隔离存储
# 每个集群的状态存储在: ${KUBEXM_DATA_DIR:-$PWD/.kubexm}/${KUBEXM_CLUSTER_NAME}/
#   ├── config/   (KUBEXM_CONFIG 键值对)
#   ├── hosts/    (KUBEXM_HOSTS 键值对)
#   └── roles/    (KUBEXM_ROLE_GROUPS 键值对)
#
# 同时保持全局数组写入 (backward compat)，
# getter 函数优先从 cluster-scoped context 读取。
# ==============================================================================

# 注意：不设置 set 选项，继承调用者的设置以避免 "cluster_name: 未绑定的变量" 错误

# 获取项目根目录（如果未设置）
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 注意：不在这里 source context.sh，因为此时 KUBEXM_CLUSTER_NAME 可能还未设置
# context.sh 将在需要时由函数内部加载

# ==============================================================================
# 辅助: 写入配置值（同时写 cluster-scoped context + 全局数组）
# ==============================================================================
_config_set() {
  local key="$1"; local value="$2"
  # 写 cluster-scoped context
  context::cluster::set_config "${key}" "${value}" 2>/dev/null || true
  # 写全局数组 (backward compat)
  KUBEXM_CONFIG["${key}"]="${value}"
}

_config_set_host() {
  local host_key="$1"; local value="$2"
  context::cluster::set_host "${host_key}" "${value}" 2>/dev/null || true
  KUBEXM_HOSTS["${host_key}"]="${value}"
}

_config_set_role() {
  local role="$1"; local members="$2"
  context::cluster::set_role_group "${role}" "${members}" 2>/dev/null || true
  KUBEXM_ROLE_GROUPS["${role}"]="${members}"
}

#######################################
# Parse hosts from host.yaml
#######################################
config::loader::parse_hosts() {
  # 加载集群隔离 context（如果尚未加载）
  if ! declare -f context::cluster::init >/dev/null 2>&1; then
    source "${KUBEXM_SCRIPT_ROOT}/internal/context/context.sh"
  fi
  
  # 初始化集群隔离 context
  context::cluster::init

  if [[ ! -f "${KUBEXM_HOST_FILE}" ]]; then
    echo "Error: host.yaml not found: ${KUBEXM_HOST_FILE}" >&2
    return 1
  fi

  local yaml_content
  yaml_content=$(cat "${KUBEXM_HOST_FILE}")

  local hosts_list
  hosts_list=$(yaml::get_list "${yaml_content}" "spec.hosts")

  if [[ -z "${hosts_list}" ]]; then
    echo "Error: No hosts found in host.yaml" >&2
    return 1
  fi

  while IFS= read -r host_line; do
    [[ -z "${host_line}" ]] && continue

    local host_name
    # Extract each field using sed (POSIX-compliant, no grep -P dependency)
    # Step 1: remove field prefix + trailing delimiter, Step 2: strip surrounding quotes
    host_name=$(echo "${host_line}" | sed -n 's/.*name:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")

    if [[ -n "${host_name}" ]]; then
      local address internal_address user password ssh_key arch
      address=$(echo "${host_line}" | sed -n 's/.*address:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")
      internal_address=$(echo "${host_line}" | sed -n 's/.*internalAddress:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")
      user=$(echo "${host_line}" | sed -n 's/.*user:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")
      password=$(echo "${host_line}" | sed -n 's/.*password:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")
      ssh_key=$(echo "${host_line}" | sed -n 's/.*ssh_key:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")
      arch=$(echo "${host_line}" | sed -n 's/.*arch:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")

      if [[ -z "${address}" ]]; then
        echo "Error: host ${host_name} is missing required 'address' field" >&2
        return 1
      fi
      if [[ "${address}" == "localhost" || "${address}" == "127.0.0.1" ]]; then
        echo "Error: host ${host_name} uses forbidden address ${address}" >&2
        return 1
      fi
      if [[ -n "${internal_address}" && ( "${internal_address}" == "localhost" || "${internal_address}" == "127.0.0.1" ) ]]; then
        echo "Error: host ${host_name} uses forbidden internalAddress ${internal_address}" >&2
        return 1
      fi

      _config_set_host "${host_name}.address" "${address}"
      _config_set_host "${host_name}.internal_address" "${internal_address}"
      _config_set_host "${host_name}.user" "${user:-root}"
      _config_set_host "${host_name}.password" "${password}"
      _config_set_host "${host_name}.ssh_key" "${ssh_key}"
      _config_set_host "${host_name}.arch" "${arch:-x86_64}"
    fi
  done <<< "${hosts_list}"

  local role_groups
  role_groups=$(yaml::get_value "${yaml_content}" "spec.roleGroups")

  if [[ -n "${role_groups}" ]]; then
    local etcd_members control_plane_members worker_members lb_members registry_members
    etcd_members=$(yaml::get_list "${yaml_content}" "spec.roleGroups.etcd")
    [[ -n "${etcd_members}" ]] && _config_set_role "etcd" "${etcd_members}"

    control_plane_members=$(yaml::get_list "${yaml_content}" "spec.roleGroups.control-plane")
    [[ -n "${control_plane_members}" ]] && _config_set_role "control-plane" "${control_plane_members}"

    worker_members=$(yaml::get_list "${yaml_content}" "spec.roleGroups.worker")
    [[ -n "${worker_members}" ]] && _config_set_role "worker" "${worker_members}"

    lb_members=$(yaml::get_list "${yaml_content}" "spec.roleGroups.loadbalancer")
    [[ -n "${lb_members}" ]] && _config_set_role "loadbalancer" "${lb_members}"

    registry_members=$(yaml::get_list "${yaml_content}" "spec.roleGroups.registry")
    [[ -n "${registry_members}" ]] && _config_set_role "registry" "${registry_members}"
  fi

  return 0
}

#######################################
# Parse config from config.yaml
#######################################
config::loader::parse_config() {
  # 加载集群隔离 context（如果尚未加载）
  if ! declare -f context::cluster::init >/dev/null 2>&1; then
    source "${KUBEXM_SCRIPT_ROOT}/internal/context/context.sh"
  fi
  
  # 初始化集群隔离 context（如果尚未初始化）
  if [[ -z "${KUBEXM_CLUSTER_CONTEXT_DIR:-}" ]]; then
    context::cluster::init
  fi

  if [[ ! -f "${KUBEXM_CONFIG_FILE}" ]]; then
    echo "Error: config.yaml not found: ${KUBEXM_CONFIG_FILE}" >&2
    return 1
  fi

  local yaml_content
  yaml_content=$(cat "${KUBEXM_CONFIG_FILE}")

  _config_set "spec.kubernetes.type" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.type")"
  _config_set "spec.kubernetes.version" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.version")"
  _config_set "spec.kubernetes.service_cidr" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.service_cidr")"
  _config_set "spec.kubernetes.pod_cidr" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.pod_cidr")"
  _config_set "spec.kubernetes.cluster_domain" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.cluster_domain")"

  _config_set "spec.etcd.type" "$(yaml::get_value "${yaml_content}" "spec.etcd.type")"
  _config_set "spec.etcd.version" "$(yaml::get_value "${yaml_content}" "spec.etcd.version")"
  _config_set "spec.etcd.mode" "$(yaml::get_value "${yaml_content}" "spec.etcd.mode")"
  _config_set "spec.etcd.data_dir" "$(yaml::get_value "${yaml_content}" "spec.etcd.data_dir")"
  local etcd_external_endpoints
  etcd_external_endpoints=$(yaml::get_list "${yaml_content}" "spec.etcd.external_endpoints" 2>/dev/null || true)
  if [[ -n "${etcd_external_endpoints}" ]]; then
    _config_set "spec.etcd.external_endpoints" "$(echo "${etcd_external_endpoints}" | tr '\n' ',' | sed 's/,$//')"
  else
    _config_set "spec.etcd.external_endpoints" ""
  fi

  _config_set "spec.runtime.type" "$(yaml::get_value "${yaml_content}" "spec.runtime.type")"
  _config_set "spec.runtime.version" "$(yaml::get_value "${yaml_content}" "spec.runtime.version")"
  _config_set "spec.runtime.cgroup_driver" "$(yaml::get_value "${yaml_content}" "spec.runtime.cgroup_driver")"

  _config_set "spec.network.plugin" "$(yaml::get_value "${yaml_content}" "spec.network.plugin")"
  _config_set "spec.network.interface" "$(yaml::get_value "${yaml_content}" "spec.network.interface")"
  _config_set "spec.network.ip_family" "$(yaml::get_value "${yaml_content}" "spec.network.ip_family")"

  _config_set "spec.loadbalancer.enabled" "$(yaml::get_value "${yaml_content}" "spec.loadbalancer.enabled")"
  _config_set "spec.loadbalancer.mode" "$(yaml::get_value "${yaml_content}" "spec.loadbalancer.mode")"
  _config_set "spec.loadbalancer.type" "$(yaml::get_value "${yaml_content}" "spec.loadbalancer.type")"
  _config_set "spec.loadbalancer.vip" "$(yaml::get_value "${yaml_content}" "spec.loadbalancer.vip")"
  _config_set "spec.loadbalancer.interface" "$(yaml::get_value "${yaml_content}" "spec.loadbalancer.interface")"
  _config_set "spec.loadbalancer.deploy_mode" "$(yaml::get_value "${yaml_content}" "spec.loadbalancer.deploy_mode")"

  _config_set "spec.mode" "$(yaml::get_value "${yaml_content}" "spec.mode")"

  _config_set "spec.addons.metrics_server.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.metrics_server.enabled")"
  _config_set "spec.addons.nodelocaldns.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.nodelocaldns.enabled")"
  _config_set "spec.addons.ingress_controller.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.ingress_controller.enabled")"
  _config_set "spec.addons.ingress_controller.type" "$(yaml::get_value "${yaml_content}" "spec.addons.ingress_controller.type")"
  _config_set "spec.addons.storage.local_path_provisioner.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.storage.local_path_provisioner.enabled")"
  _config_set "spec.addons.dashboard.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.dashboard.enabled")"
  _config_set "spec.addons.cert_manager.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.cert_manager.enabled")"
  _config_set "spec.addons.monitoring.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.monitoring.enabled")"
  _config_set "spec.addons.logging.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.logging.enabled")"
  _config_set "spec.addons.external_dns.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.external_dns.enabled")"
  _config_set "spec.addons.istio.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.istio.enabled")"
  _config_set "spec.addons.longhorn.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.longhorn.enabled")"
  _config_set "spec.addons.openebs.enabled" "$(yaml::get_value "${yaml_content}" "spec.addons.openebs.enabled")"

  _config_set "spec.registry.enable" "$(yaml::get_value "${yaml_content}" "spec.registry.enable")"
  _config_set "spec.registry.host" "$(yaml::get_value "${yaml_content}" "spec.registry.host")"
  _config_set "spec.registry.port" "$(yaml::get_value "${yaml_content}" "spec.registry.port")"
  _config_set "spec.registry.data_dir" "$(yaml::get_value "${yaml_content}" "spec.registry.data_dir")"
  _config_set "spec.registry.auth.enabled" "$(yaml::get_value "${yaml_content}" "spec.registry.auth.enabled")"
  _config_set "spec.registry.auth.username" "$(yaml::get_value "${yaml_content}" "spec.registry.auth.username")"
  _config_set "spec.registry.auth.password" "$(yaml::get_value "${yaml_content}" "spec.registry.auth.password")"
  _config_set "spec.registry.tls.enabled" "$(yaml::get_value "${yaml_content}" "spec.registry.tls.enabled")"
  _config_set "spec.registry.tls.cert_file" "$(yaml::get_value "${yaml_content}" "spec.registry.tls.cert_file")"
  _config_set "spec.registry.tls.key_file" "$(yaml::get_value "${yaml_content}" "spec.registry.tls.key_file")"

  local arch_list
  arch_list=$(yaml::get_list "${yaml_content}" "spec.arch")
  if [[ -n "${arch_list}" ]]; then
    _config_set "spec.arch" "$(echo "${arch_list}" | tr '\n' ',' | sed 's/,$//')"
  else
    _config_set "spec.arch" ""
  fi

  # Production-grade advanced config fields
  _config_set "spec.kubernetes.apiserver.audit.enabled" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.apiserver.audit.enabled")"
  _config_set "spec.kubernetes.apiserver.audit.log_path" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.apiserver.audit.log_path")"
  _config_set "spec.kubernetes.apiserver.audit.max_age" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.apiserver.audit.max_age")"
  _config_set "spec.kubernetes.apiserver.audit.max_backup" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.apiserver.audit.max_backup")"
  _config_set "spec.kubernetes.apiserver.audit.max_size" "$(yaml::get_value "${yaml_content}" "spec.kubernetes.apiserver.audit.max_size")"

  local etcd_extra_args
  etcd_extra_args=$(yaml::get_value "${yaml_content}" "spec.etcd.extra_args" 2>/dev/null || true)
  [[ -n "${etcd_extra_args}" ]] && _config_set "spec.etcd.extra_args" "${etcd_extra_args}"

  _config_set "spec.nodes.kubelet.kube_reserved_cpu" "$(yaml::get_value "${yaml_content}" "spec.nodes.kubelet.kube_reserved.cpu")"
  _config_set "spec.nodes.kubelet.kube_reserved_mem" "$(yaml::get_value "${yaml_content}" "spec.nodes.kubelet.kube_reserved.memory")"
  _config_set "spec.nodes.kubelet.system_reserved_cpu" "$(yaml::get_value "${yaml_content}" "spec.nodes.kubelet.system_reserved.cpu")"
  _config_set "spec.nodes.kubelet.system_reserved_mem" "$(yaml::get_value "${yaml_content}" "spec.nodes.kubelet.system_reserved.memory")"
  _config_set "spec.nodes.kubelet.eviction_hard_memory" "$(yaml::get_value "${yaml_content}" "spec.nodes.kubelet.eviction_hard.memory_available")"

  _config_set "spec.certificates.validity_days" "$(yaml::get_value "${yaml_content}" "spec.certificates.validity_days")"
  _config_set "spec.certificates.auto_renew" "$(yaml::get_value "${yaml_content}" "spec.certificates.auto_renew")"

  _config_set "spec.backup.etcd.enabled" "$(yaml::get_value "${yaml_content}" "spec.backup.etcd.enabled")"
  _config_set "spec.backup.etcd.schedule" "$(yaml::get_value "${yaml_content}" "spec.backup.etcd.schedule")"
  _config_set "spec.backup.etcd.retention" "$(yaml::get_value "${yaml_content}" "spec.backup.etcd.retention")"
  _config_set "spec.backup.etcd.backup_dir" "$(yaml::get_value "${yaml_content}" "spec.backup.etcd.backup_dir")"

  _config_set "spec.advanced.download.retry" "$(yaml::get_value "${yaml_content}" "spec.advanced.download.retry")"
  _config_set "spec.advanced.deploy.parallel" "$(yaml::get_value "${yaml_content}" "spec.advanced.deploy.parallel")"
  _config_set "spec.advanced.image_pull_policy" "$(yaml::get_value "${yaml_content}" "spec.advanced.image_pull_policy")"

  return 0
}

export -f config::loader::parse_hosts
export -f config::loader::parse_config
