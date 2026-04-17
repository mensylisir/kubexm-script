#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Config Getters (etcd)
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

config::getters::get_etcd_type() {
  local raw
  raw=$(config::get "spec.etcd.type" "$(defaults::get_etcd_type)")
  domain::normalize_etcd_type "${raw}"
}

export -f config::getters::get_etcd_type
