#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Nginx Load Balancer Manager (Render Only)
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"

#######################################
# 生成Nginx配置文件
# Arguments:
#   $1 - 输出目录
#   $2 - 后端服务器列表（IP:PORT 或 IP）
#   $3 - 监听端口（可选）
# Returns:
#   0 on success, 1 on failure
#######################################
nginx::generate_config() {
  local output_dir="$1"
  local backend_servers="$2"
  local listen_port="${3:-$(defaults::get_api_server_port)}"

  log::info "Generating Nginx configuration..."

  local upstream_servers=""
  local server
  for server in ${backend_servers}; do
    if [[ "${server}" != *:* ]]; then
      server="${server}:${listen_port}"
    fi
    upstream_servers+="        server ${server};"$'\n'
  done

  local nginx_cfg
  nginx_cfg=$(cat <<CFG_EOF
events {
    worker_connections 1024;
}
stream {
    upstream kube_apiserver {
${upstream_servers%$'\n'}
    }
    server {
        listen ${listen_port};
        proxy_pass kube_apiserver;
        proxy_timeout 3s;
        proxy_connect_timeout 1s;
    }
}
CFG_EOF
  )

  mkdir -p "${output_dir}"
  printf '%s\n' "${nginx_cfg}" > "${output_dir}/nginx.conf"

  log::success "Nginx configuration generated: ${output_dir}/nginx.conf"
  return 0
}

export -f nginx::generate_config
