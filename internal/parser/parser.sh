#!/usr/bin/env bash
set -euo pipefail

parser::load_config() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  config::parse_config
}

parser::load_hosts() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  config::parse_hosts
}
