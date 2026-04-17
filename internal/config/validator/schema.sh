#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Config Validator (Schema)
# ==============================================================================
# 增强型 Schema 验证：验证必需字段、取值范围、依赖关系
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

config::validator::validate_config() {
  local config_file="${1:-}"

  if [[ ! -f "${config_file}" ]]; then
    echo "Config file not found: ${config_file}" >&2
    return 1
  fi

  local config_content
  config_content=$(cat "${config_file}")

  # Basic structure
  for field in "kind:" "apiVersion:" "spec:"; do
    if ! echo "${config_content}" | grep -q "${field}"; then
      echo "Invalid config: ${field} not found" >&2
      return 1
    fi
  done

  # Validate kind value
  local kind
  kind=$(yaml::get_value "${config_content}" "kind" 2>/dev/null || true)
  if [[ "${kind}" != "ClusterConfig" ]]; then
    echo "Invalid config: kind must be 'ClusterConfig', got '${kind}'" >&2
    return 1
  fi

  # Validate required spec fields
  local k8s_type k8s_version etcd_type runtime_type network_plugin
  k8s_type=$(yaml::get_value "${config_content}" "spec.kubernetes.type" 2>/dev/null || true)
  k8s_version=$(yaml::get_value "${config_content}" "spec.kubernetes.version" 2>/dev/null || true)
  etcd_type=$(yaml::get_value "${config_content}" "spec.etcd.type" 2>/dev/null || true)
  runtime_type=$(yaml::get_value "${config_content}" "spec.runtime.type" 2>/dev/null || true)
  network_plugin=$(yaml::get_value "${config_content}" "spec.network.plugin" 2>/dev/null || true)

  # Validate kubernetes type
  case "${k8s_type}" in
    kubeadm|kubexm) ;;
    "") echo "Invalid config: spec.kubernetes.type is required" >&2; return 1 ;;
    *) echo "Invalid config: spec.kubernetes.type must be 'kubeadm' or 'kubexm', got '${k8s_type}'" >&2; return 1 ;;
  esac

  # Validate etcd type
  case "${etcd_type}" in
    kubeadm|kubexm|exists) ;;
    "") echo "Warning: spec.etcd.type not set, defaulting to match kubernetes.type" >&2 ;;
    *) echo "Invalid config: spec.etcd.type must be 'kubeadm', 'kubexm', or 'exists', got '${etcd_type}'" >&2; return 1 ;;
  esac

  # Validate runtime type
  case "${runtime_type}" in
    containerd|docker|crio|cri_dockerd) ;;
    "") echo "Warning: spec.runtime.type not set, defaulting to containerd" >&2 ;;
    *) echo "Invalid config: spec.runtime.type must be 'containerd', 'docker', 'crio', or 'cri_dockerd', got '${runtime_type}'" >&2; return 1 ;;
  esac

  # Validate network plugin
  case "${network_plugin}" in
    calico|flannel|cilium) ;;
    "") echo "Warning: spec.network.plugin not set, defaulting to calico" >&2 ;;
    *) echo "Invalid config: spec.network.plugin must be 'calico', 'flannel', or 'cilium', got '${network_plugin}'" >&2; return 1 ;;
  esac

  # Validate CIDR format (basic check)
  local service_cidr pod_cidr
  service_cidr=$(yaml::get_value "${config_content}" "spec.kubernetes.service_cidr" 2>/dev/null || true)
  pod_cidr=$(yaml::get_value "${config_content}" "spec.kubernetes.pod_cidr" 2>/dev/null || true)

  if [[ -n "${service_cidr}" ]] && ! echo "${service_cidr}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'; then
    echo "Warning: spec.kubernetes.service_cidr '${service_cidr}' may not be valid CIDR" >&2
  fi
  if [[ -n "${pod_cidr}" ]] && ! echo "${pod_cidr}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'; then
    echo "Warning: spec.kubernetes.pod_cidr '${pod_cidr}' may not be valid CIDR" >&2
  fi

  # Warn if CIDRs overlap
  if [[ -n "${service_cidr}" && -n "${pod_cidr}" && "${service_cidr}" == "${pod_cidr}" ]]; then
    echo "Warning: service_cidr and pod_cidr are identical: ${service_cidr}" >&2
  fi

  # Validate version format
  if [[ -n "${k8s_version}" ]] && ! echo "${k8s_version}" | grep -qE '^v?[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Invalid config: spec.kubernetes.version '${k8s_version}' is not valid semver" >&2
    return 1
  fi

  return 0
}

config::validator::validate_hosts() {
  local hosts_file="${1:-}"

  if [[ ! -f "${hosts_file}" ]]; then
    echo "Hosts file not found: ${hosts_file}" >&2
    return 1
  fi

  local hosts_content
  hosts_content=$(cat "${hosts_file}")

  # Basic structure
  for field in "kind:" "apiVersion:" "spec:" "hosts:"; do
    if ! echo "${hosts_content}" | grep -q "${field}"; then
      echo "Invalid hosts: ${field} not found" >&2
      return 1
    fi
  done

  # Validate kind
  local kind
  kind=$(yaml::get_value "${hosts_content}" "kind" 2>/dev/null || true)
  if [[ "${kind}" != "HostList" ]]; then
    echo "Invalid hosts: kind must be 'HostList', got '${kind}'" >&2
    return 1
  fi

  # Validate each host has required fields
  local hosts_list
  hosts_list=$(yaml::get_list "${hosts_content}" "spec.hosts" 2>/dev/null || true)
  if [[ -z "${hosts_list}" ]]; then
    echo "Invalid hosts: spec.hosts is empty" >&2
    return 1
  fi

  local host_count=0
  while IFS= read -r host_line; do
    [[ -z "${host_line}" ]] && continue
    host_count=$((host_count + 1))

    local host_name address
    host_name=$(echo "${host_line}" | sed -n 's/.*name:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")
    address=$(echo "${host_line}" | sed -n 's/.*address:\s*//; s/[,}].*//p' | sed "s/^[\"']//; s/[\"']\$//")

    if [[ -z "${host_name}" ]]; then
      echo "Invalid host entry #${host_count}: missing 'name'" >&2
      return 1
    fi
    if [[ -z "${address}" ]]; then
      echo "Invalid host '${host_name}': missing 'address'" >&2
      return 1
    fi
    if [[ "${address}" == "localhost" || "${address}" == "127.0.0.1" ]]; then
      echo "Invalid host '${host_name}': forbidden address '${address}'" >&2
      return 1
    fi
  done <<< "${hosts_list}"

  if [[ ${host_count} -eq 0 ]]; then
    echo "Invalid hosts: no valid host entries found" >&2
    return 1
  fi

  return 0
}

export -f config::validator::validate_config
export -f config::validator::validate_hosts
