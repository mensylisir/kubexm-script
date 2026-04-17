#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Config Getters (LoadBalancer)
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

config::getters::get_loadbalancer_enabled() {
  config::get "spec.loadbalancer.enabled" "$(defaults::get_loadbalancer_enabled)"
}

config::getters::get_loadbalancer_mode() {
  local raw
  raw=$(config::get "spec.loadbalancer.mode" "$(defaults::get_loadbalancer_mode)")
  domain::normalize_lb_mode "${raw}"
}

config::getters::get_loadbalancer_type() {
  local default_type="$(defaults::get_loadbalancer_type)"
  local mode
  mode=$(config::getters::get_loadbalancer_mode)

  if [[ "${mode}" == "kube-vip" ]]; then
    default_type="kube-vip"
  elif [[ "${mode}" == "exists" ]]; then
    default_type="exists"
  elif [[ "${mode}" == "external" ]]; then
    default_type="kubexm-kh"
  fi

  local raw
  raw=$(config::get "spec.loadbalancer.type" "${default_type}")
  domain::normalize_lb_type "${raw}"
}

export -f config::getters::get_loadbalancer_enabled
export -f config::getters::get_loadbalancer_mode
export -f config::getters::get_loadbalancer_type
