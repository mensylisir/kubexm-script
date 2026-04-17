#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Config Getters (Kubernetes)
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

config::getters::get_kubernetes_type() {
  config::get "spec.kubernetes.type" "$(defaults::get_kubernetes_type)"
}

config::getters::get_apiserver_endpoint() {
  local endpoint
  endpoint=$(config::get "spec.kubernetes.apiserver.endpoint" "")
  if [[ -n "${endpoint}" ]]; then
    echo "${endpoint}"
    return 0
  fi

  local address
  address=$(config::get_apiserver_address)
  if [[ -z "${address}" ]]; then
    address=$(config::get_loadbalancer_vip)
  fi
  if [[ -z "${address}" ]]; then
    local first_master
    first_master=$(config::get_role_members "control-plane" | awk '{print $1}')
    if [[ -n "${first_master}" ]]; then
      address=$(config::get_host_param "${first_master}" "address")
    fi
  fi

  local port
  port=$(config::get_apiserver_port)

  if [[ -z "${address}" ]]; then
    echo ""
    return 0
  fi

  if [[ "${address}" == *:* ]]; then
    echo "${address}"
  else
    echo "${address}:${port}"
  fi
}

export -f config::getters::get_kubernetes_type
export -f config::getters::get_apiserver_endpoint
