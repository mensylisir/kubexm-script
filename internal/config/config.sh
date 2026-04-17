#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - YAML Configuration Parser
# ==============================================================================
# 支持解析YAML格式的host.yaml和config.yaml文件
# 遵循Kubernetes风格配置：apiVersion, kind, metadata, spec
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 数据目录根（默认 PWD/.kubexm，可通过环境变量覆盖）
KUBEXM_DATA_DIR="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}"

# 配置路径（优先从 conf/clusters/ 读取，这是用户编辑配置的目录）
# 如果 conf/clusters/ 不存在，则回退到 .kubexm/clusters/
if [[ -d "${KUBEXM_SCRIPT_ROOT}/conf/clusters" ]]; then
  KUBEXM_CLUSTERS_DIR="${KUBEXM_CLUSTERS_DIR:-${KUBEXM_SCRIPT_ROOT}/conf/clusters}"
else
  KUBEXM_CLUSTERS_DIR="${KUBEXM_CLUSTERS_DIR:-${KUBEXM_DATA_DIR}/clusters}"
fi

KUBEXM_CLUSTER_NAME="${KUBEXM_CLUSTER_NAME-}"
KUBEXM_HOST_FILE="${KUBEXM_HOST_FILE:-${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml}"
KUBEXM_CONFIG_FILE="${KUBEXM_CONFIG_FILE:-${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml}"

# 统一语义层（兼容值归一、策略规则）
source "${KUBEXM_SCRIPT_ROOT}/internal/config/domain/domain.sh"

# 集群隔离 Context (多集群并发支持)
source "${KUBEXM_SCRIPT_ROOT}/internal/context/context.sh"

# 配置模块（PR-2 模块化拆分）
source "${KUBEXM_SCRIPT_ROOT}/internal/config/loader.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/getters/kubernetes.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/getters/etcd.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/getters/loadbalancer.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/validator/schema.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/validator/consistency.sh"

# 全局变量存储配置数据（仅在未声明时声明，避免重复source时重置）
if [[ -z "${KUBEXM_CONFIG_DECLARED:-}" ]]; then
  declare -A KUBEXM_CONFIG
  declare -A KUBEXM_HOSTS
  declare -A KUBEXM_ROLE_GROUPS
  export KUBEXM_CONFIG_DECLARED=1
fi

# ==============================================================================
# YAML解析辅助函数
# ==============================================================================

#######################################
# 简单YAML解析器 - 获取值
# Arguments:
#   $1 - YAML内容
#   $2 - 键路径 (如: spec.kubernetes.version)
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   配置值到stdout
#######################################
yaml::get_value() {
  local yaml_content="$1"
  local key_path="$2"

  # 获取xmyq工具路径
  local xmyq_bin="${KUBEXM_ROOT:-${KUBEXM_SCRIPT_ROOT}}/bin/xmyq"

  # 使用xmyq进行解析
  if [[ -x "${xmyq_bin}" ]]; then
    local tmp_file
    tmp_file=$(mktemp /tmp/kubexm_yaml_XXXXXX.yaml)
    echo "${yaml_content}" > "${tmp_file}"
    
    local result
    local exit_code=0
    result=$("${xmyq_bin}" -r ".${key_path}" "${tmp_file}" 2>&1) || exit_code=$?
    rm -f "${tmp_file}"

    # 检查 xmyq 是否执行成功
    if [[ ${exit_code} -ne 0 ]]; then
      # 仅在 DEBUG 模式下记录解析错误，避免干扰正常输出
      if [[ "${KUBEXM_DEBUG:-false}" == "true" ]]; then
        log::debug "xmyq 解析警告 (key: ${key_path}): ${result}"
      fi
      # 返回空字符串以保持兼容性
      echo ""
      return 0
    fi

    # 兼容缺失字段/空字段：统一返回空字符串，避免 set -e 因返回码中断流程
    if [[ "${result}" == "null" ]]; then
      echo ""
      return 0
    fi

    echo "${result}"
    return 0
  fi

  # xmyq不可用时，使用简单的 grep/sed 回退解析（仅支持最后一级 key）
  local simple_key="${key_path##*.}"
  local value
  value=$(echo "${yaml_content}" | grep -E "^[[:space:]]*${simple_key}:" | head -1 | sed 's/^[[:space:]]*[^:]*:[[:space:]]*//' | sed 's/["\\047]//g')

  echo "${value}"
  return 0
}

#######################################
# 解析YAML列表
# Arguments:
#   $1 - YAML内容
#   $2 - 列表路径 (如: spec.arch)
# Returns:
#   0 on success, 1 on failure
# Outputs:
#   列表项到stdout（每行一项）
#######################################
yaml::get_list() {
  local yaml_content="$1"
  local list_path="$2"

  # 获取xmyq工具路径
  local xmyq_bin="${KUBEXM_ROOT:-${KUBEXM_SCRIPT_ROOT}}/bin/xmyq"
  if [[ ! -x "${xmyq_bin}" ]]; then
    # 回退到简单awk解析
    echo "${yaml_content}" | awk -F'[[:space:]]*-[[:space:]]*' 'NF>1 {print $NF}'
    return 1
  fi

  # 使用xmyq提取列表（写入临时文件），使用 -r 参数输出纯文本
  local tmp_file
  tmp_file=$(mktemp /tmp/kubexm_yaml_XXXXXX.yaml)
  echo "${yaml_content}" > "${tmp_file}"

  # 获取列表内容（raw格式，每行一项）
  local list_content
  list_content=$("${xmyq_bin}" -r "${list_path}" "${tmp_file}" 2>/dev/null)
  rm -f "${tmp_file}"

  if [[ -z "${list_content}" ]]; then
    return 1
  fi

  # 直接输出，无需sed处理
  echo "${list_content}"
}

#######################################
# 解析主机信息（从host.yaml）
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
config::parse_hosts() {
  config::loader::parse_hosts
}

#######################################
# 从配置文件获取值
# Arguments:
#   $1 - 配置文件路径
#   $2 - 键路径 (如: spec.kubernetes.version)
#   $3 - 默认值
# Returns:
#   配置值到stdout
#######################################
config::get_value() {
  local config_file="$1"
  local key_path="$2"
  local default_value="$3"

  if [[ ! -f "${config_file}" ]]; then
    echo "${default_value}"
    return 1
  fi

  local config_content
  config_content=$(cat "${config_file}")
  local value
  value=$(yaml::get_value "${config_content}" "${key_path}" 2>/dev/null)

  if [[ -n "${value}" ]]; then
    echo "${value}"
  else
    echo "${default_value}"
  fi
}

#######################################
# 解析配置信息（从config.yaml）
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
config::parse_config() {
  config::loader::parse_config
}

#######################################
# 获取配置值（多集群并发安全）
# 优先从 cluster-scoped context 读取，回退到全局数组
# Arguments:
#   $1 - 配置键
#   $2 - 默认值（可选）
# Returns:
#   配置值或默认值
#######################################
config::get() {
  local key="$1"
  local default="${2:-}"

  # 优先：从 cluster-scoped context 读取（多集群隔离）
  local ctx_value
  if ctx_value="$(context::cluster::get_config "${key}" 2>/dev/null)" && [[ -n "${ctx_value}" ]]; then
    echo "${ctx_value}"
    return 0
  fi

  # 回退1：尝试原始键（全局数组 backward compat）
  if [[ -n "${KUBEXM_CONFIG["$key"]:-}" ]]; then
    echo "${KUBEXM_CONFIG["$key"]}"
    return 0
  fi

  # 回退2：尝试 snake_case 转 camelCase
  local camel_key
  camel_key=$(config::_to_camel_case "$key")
  if [[ "$camel_key" != "$key" ]] && [[ -n "${KUBEXM_CONFIG["$camel_key"]:-}" ]]; then
    echo "${KUBEXM_CONFIG["$camel_key"]}"
    return 0
  fi

  # 回退3：尝试 camelCase 转 snake_case
  local snake_key
  snake_key=$(config::_to_snake_case "$key")
  if [[ "$snake_key" != "$key" ]] && [[ -n "${KUBEXM_CONFIG["$snake_key"]:-}" ]]; then
    echo "${KUBEXM_CONFIG["$snake_key"]}"
    return 0
  fi

  echo "${default}"
}

#######################################
# 内部函数: snake_case 转 camelCase
#######################################
config::_to_camel_case() {
  echo "$1" | sed -E 's/_([a-z])/\U\1/g'
}

#######################################
# 内部函数: camelCase 转 snake_case
#######################################
config::_to_snake_case() {
  echo "$1" | sed -E 's/([A-Z])/_\L\1/g' | sed 's/^_//'
}

#######################################
# 获取主机参数（多集群并发安全）
# 优先从 cluster-scoped context 读取，回退到全局数组
# Arguments:
#   $1 - 主机名
#   $2 - 参数名
#   $3 - 默认值（可选）
# Returns:
#   参数值或默认值
#######################################
config::get_host_param() {
  local host_name="$1"
  local param="$2"
  local default="${3:-}"

  # 优先：从 cluster-scoped context 读取
  local ctx_value
  if ctx_value="$(context::cluster::get_host "${host_name}.${param}" 2>/dev/null)" && [[ -n "${ctx_value}" ]]; then
    echo "${ctx_value}"
    return 0
  fi

  # 回退：全局数组 (backward compat)
  if [[ -n "${KUBEXM_HOSTS[${host_name}.${param}]:-}" ]]; then
    echo "${KUBEXM_HOSTS[${host_name}.${param}]}"
    return 0
  fi

  echo "${default}"
}

#######################################
# 获取所有主机名列表（多集群并发安全）
# 优先从 cluster-scoped context 读取，回退到全局数组
# Arguments:
#   None
# Returns:
#   主机名列表（空格分隔）
#######################################
config::get_all_host_names() {
  # 优先：从 cluster-scoped context 读取
  local ctx_hosts
  if ctx_hosts="$(context::cluster::list_hosts 2>/dev/null)" && [[ -n "${ctx_hosts}" ]]; then
    echo "${ctx_hosts}"
    return 0
  fi

  # 回退：遍历全局数组
  local host_names=""
  for key in "${!KUBEXM_HOSTS[@]}"; do
    if [[ "${key}" =~ \.address$ ]]; then
      local host_name="${key%.address}"
      host_names+="${host_name} "
    fi
  done
  echo "${host_names}"
}

#######################################
# 获取角色组所有成员（多集群并发安全）
# 优先从 cluster-scoped context 读取，回退到全局数组
# Arguments:
#   $1 - 角色组名称 (etcd, control-plane, worker, loadbalancer, registry)
# Returns:
#   成员列表（空格分隔）
#######################################
config::get_role_members() {
  local role="$1"

  # 优先：从 cluster-scoped context 读取
  local members
  if members="$(context::cluster::get_role_group "${role}" 2>/dev/null)" && [[ -n "${members}" ]]; then
    echo "${members}"
    return 0
  fi

  # 回退1：直接读取全局数组
  members="${KUBEXM_ROLE_GROUPS[$role]:-}"
  if [[ -n "${members}" ]]; then
    echo "${members}"
    return 0
  fi

  # 回退2：role alias compatibility (master <-> control-plane)
  case "${role}" in
    master)
      members="${KUBEXM_ROLE_GROUPS[control-plane]:-}"
      ;;
    control-plane)
      members="${KUBEXM_ROLE_GROUPS[master]:-}"
      ;;
  esac

  echo "${members}"
}


#######################################
# 验证配置完整性
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
config::validate() {
  local errors=0

  # 检查必需的配置项
  local k8s_type
  k8s_type="$(config::get_kubernetes_type)"
  if [[ -z "${k8s_type}" ]]; then
    echo "Error: kubernetes.type not configured" >&2
    ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  fi

  local etcd_type
  etcd_type="$(config::get_etcd_type)"
  if [[ -z "${etcd_type}" ]]; then
    echo "Error: etcd.type not configured" >&2
    ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  fi

  # 检查etcd组（仅 etcd_type=kubexm 时要求独立etcd角色）
  if [[ "${etcd_type}" == "kubexm" ]]; then
    local etcd_members
    etcd_members=$(config::get_role_members "etcd")
    if [[ -z "${etcd_members}" ]]; then
      echo "Error: etcd.type=kubexm requires etcd role members" >&2
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  # 检查control-plane组
  local cp_members
  cp_members=$(config::get_role_members "control-plane")
  if [[ -z "${cp_members}" ]]; then
    echo "Error: No control-plane members configured" >&2
    ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  fi

  # 检查loadbalancer角色（仅 lb_mode=external 时要求独立loadbalancer角色）
  local lb_enabled lb_mode
  lb_enabled=$(config::get_loadbalancer_enabled)
  lb_mode=$(config::get_loadbalancer_mode)
  if [[ "${lb_enabled}" == "true" && "${lb_mode}" == "external" ]]; then
    local lb_members
    lb_members=$(config::get_role_members "loadbalancer")
    if [[ -z "${lb_members}" ]]; then
      echo "Error: loadbalancer.mode=external requires loadbalancer role members" >&2
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  # 检查registry角色（仅 registry.enable=true 时要求registry角色）
  local registry_enabled
  registry_enabled=$(config::get_registry_enabled)
  if [[ "${registry_enabled}" == "true" ]]; then
    local registry_members
    registry_members=$(config::get_role_members "registry")
    if [[ -z "${registry_members}" ]]; then
      echo "Error: registry.enable=true requires registry role members" >&2
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  if [[ ${errors} -gt 0 ]]; then
    echo "Configuration validation failed with ${errors} error(s)" >&2
    return 1
  fi

  return 0
}

#######################################
# 获取所有主机的 IP 地址列表
# Returns:
#   IP 地址列表（空格分隔）
#######################################
config::get_all_host_addresses() {
  local names
  names=$(config::get_all_host_names 2>/dev/null || true)
  local addresses=""
  for name in ${names}; do
    local addr
    addr=$(config::get_host_param "${name}" "address" 2>/dev/null || true)
    if [[ -n "${addr}" ]]; then
      addresses+="${addr} "
    fi
  done
  echo "${addresses}"
}

# 导出函数
export -f yaml::get_value
export -f yaml::get_list
export -f config::parse_hosts
export -f config::parse_config
export -f config::get
export -f config::get_host_param
export -f config::get_role_members
export -f config::get_all_host_addresses
export -f config::validate

#######################################
# 获取集群名称
# Arguments:
#   $1 - 配置文件路径
# Returns:
#   集群名称
#######################################
config::get_cluster_name() {
  local config_file="${1:-}"
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"

  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    local config_content
    config_content=$(cat "${config_file}")
    local name
    name=$(yaml::get_value "${config_content}" "metadata.name" 2>/dev/null)
    if [[ -n "${name}" ]]; then
      cluster_name="${name}"
    fi
  fi

  echo "${cluster_name}"
}

#######################################
# 获取Cluster CIDR
# Arguments:
#   $1 - 配置文件路径
# Returns:
#   Cluster CIDR
#######################################
config::get_cluster_cidr() {
  local config_file="$1"
  local cluster_cidr
  cluster_cidr=$(defaults::get_cluster_cidr)

  if [[ -f "${config_file}" ]]; then
    local config_content
    config_content=$(cat "${config_file}")
    local cidr
    cidr=$(yaml::get_value "${config_content}" "spec.kubernetes.podCidr" 2>/dev/null)
    if [[ -n "${cidr}" ]]; then
      cluster_cidr="${cidr}"
    fi
  fi

  echo "${cluster_cidr}"
}

#######################################
# 获取Image Registry
# Arguments:
#   $1 - 配置文件路径
# Returns:
#   Image Registry URL
#######################################
config::get_image_registry() {
  local config_file="${1:-}"
  local registry=""

  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    local config_content
    config_content=$(cat "${config_file}")
    registry=$(yaml::get_value "${config_content}" "spec.runtime.registry.mirrors.docker.io.endpoint" 2>/dev/null)
  else
    registry=$(config::get "spec.runtime.registry.mirrors.docker.io.endpoint" "")
  fi

  if [[ -z "${registry}" ]]; then
    registry="registry.k8s.io"
  fi

  echo "${registry}"
}

#######################################
# 获取VIP
# Arguments:
#   $1 - 配置文件路径
# Returns:
#   VIP地址
#######################################
config::get_vip() {
  local config_file="$1"
  local vip=""

  if [[ -f "${config_file}" ]]; then
    local config_content
    config_content=$(cat "${config_file}")
    vip=$(yaml::get_value "${config_content}" "spec.loadBalancer.vip" 2>/dev/null)
  fi

  echo "${vip}"
}

#######################################
# 获取Master节点列表
# Arguments:
#   $1 - 主机文件路径
# Returns:
#   Master节点IP列表（空格分隔）
#######################################
config::get_master_nodes() {
  local hosts_file="$1"
  local masters=""

  if [[ -f "${hosts_file}" ]]; then
    masters=$(config::get_role_members "master")
  fi

  echo "${masters}"
}

#######################################
# 获取Etcd节点列表
# Arguments:
#   $1 - 主机文件路径
# Returns:
#   Etcd节点IP列表（空格分隔）
#######################################
config::get_etcd_nodes() {
  local hosts_file="$1"
  local etcds=""

  if [[ -f "${hosts_file}" ]]; then
    etcds=$(config::get_role_members "etcd")
  fi

  echo "${etcds}"
}

# 导出新函数
export -f config::get_cluster_name
export -f config::get_cluster_cidr
export -f config::get_image_registry
export -f config::get_vip
export -f config::get_master_nodes
export -f config::get_etcd_nodes

#######################################
# 验证配置文件
# Arguments:
#   $1 - 配置文件路径
# Returns:
#   0 on success, 1 on failure
#######################################
config::validate_config() {
  local config_file="$1"
  config::validator::validate_config "${config_file}"
}

#######################################
# 验证主机文件
# Arguments:
#   $1 - 主机文件路径
# Returns:
#   0 on success, 1 on failure
#######################################
config::validate_hosts() {
  local hosts_file="$1"
  config::validator::validate_hosts "${hosts_file}"
}

# 导出验证函数
export -f config::validate_config
export -f config::validate_hosts

# ==============================================================================
# 扩展配置解析函数 - 支持完整配置项
# ==============================================================================

#######################################
# 获取模式（online/offline）
#######################################
config::get_mode() {
  config::get "spec.mode" "offline"
}
export -f config::get_mode

#######################################
# 获取架构列表（多集群并发安全）
#######################################
config::get_arch_list() {
  # 优先：从 cluster-scoped context 读取
  local ctx_value
  if ctx_value="$(context::cluster::get_config "spec.arch" 2>/dev/null)" && [[ -n "${ctx_value}" ]]; then
    echo "${ctx_value}"
    return 0
  fi

  # 回退1：从全局数组读取
  local arch_list="${KUBEXM_CONFIG[spec.arch]:-}"
  if [[ -n "${arch_list}" ]]; then
    echo "${arch_list}"
    return 0
  fi

  # 回退2：返回默认值
  defaults::get_arch_list
}
export -f config::get_arch_list

#######################################
# 获取Kubernetes部署类型
#######################################
config::get_kubernetes_type() {
  config::getters::get_kubernetes_type
}
export -f config::get_kubernetes_type

#######################################
# 获取API Server访问端点(host:port)
#######################################
config::get_apiserver_endpoint() {
  config::getters::get_apiserver_endpoint
}
export -f config::get_apiserver_endpoint

#######################################
# 获取Kubernetes版本
#######################################
config::get_kubernetes_version() {
  config::get "spec.kubernetes.version" "$(defaults::get_kubernetes_version)"
}
export -f config::get_kubernetes_version

#######################################
# 获取Service CIDR
#######################################
config::get_service_cidr() {
  local config_file="${1:-}"
  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    # 兼容旧代码：从文件读取
    local config_content
    config_content=$(cat "${config_file}")
    local cidr
    cidr=$(yaml::get_value "${config_content}" "spec.kubernetes.serviceCidr" 2>/dev/null)
    if [[ -n "${cidr}" ]]; then
      echo "${cidr}"
    else
      defaults::get_service_cidr
    fi
  else
    # 新代码：从预加载配置读取
    config::get "spec.kubernetes.service_cidr" "$(defaults::get_service_cidr)"
  fi
}
export -f config::get_service_cidr

#######################################
# 获取Pod CIDR
#######################################
config::get_pod_cidr() {
  local config_file="${1:-}"
  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    # 兼容旧代码：从文件读取
    local config_content
    config_content=$(cat "${config_file}")
    local cidr
    cidr=$(yaml::get_value "${config_content}" "spec.kubernetes.podCidr" 2>/dev/null)
    if [[ -n "${cidr}" ]]; then
      echo "${cidr}"
    else
      defaults::get_pod_cidr
    fi
  else
    # 新代码：从预加载配置读取
    config::get "spec.kubernetes.pod_cidr" "$(defaults::get_pod_cidr)"
  fi
}
export -f config::get_pod_cidr

#######################################
# 获取集群域名
#######################################
config::get_cluster_domain() {
  config::get "spec.kubernetes.cluster_domain" "cluster.local"
}
export -f config::get_cluster_domain

#######################################
# 获取API Server绑定地址
#######################################
config::get_apiserver_address() {
  config::get "spec.kubernetes.apiserver.advertise_address" ""
}
export -f config::get_apiserver_address

#######################################
# 获取API Server端口
#######################################
config::get_apiserver_port() {
  config::get "spec.kubernetes.apiserver.secure_port" "6443"
}
export -f config::get_apiserver_port

#######################################
# 获取Kube-Proxy模式
#######################################
config::get_kube_proxy_mode() {
  config::get "spec.kubernetes.kube_proxy.mode" "iptables"
}
export -f config::get_kube_proxy_mode

#######################################
# 获取etcd部署类型
#######################################
config::get_etcd_type() {
  config::getters::get_etcd_type
}
export -f config::get_etcd_type

#######################################
# 获取etcd版本
#######################################
config::get_etcd_version() {
  config::get "spec.etcd.version" "v3.5.13"
}
export -f config::get_etcd_version

#######################################
# 获取etcd部署模式
#######################################
config::get_etcd_mode() {
  config::get "spec.etcd.mode" "stacked"
}
export -f config::get_etcd_mode

#######################################
# 获取etcd数据目录
#######################################
config::get_etcd_data_dir() {
  config::get "spec.etcd.data_dir" "/var/lib/etcd"
}
export -f config::get_etcd_data_dir

#######################################
# 获取外部etcd endpoints（逗号分隔）
#######################################
config::get_etcd_external_endpoints() {
  config::get "spec.etcd.external_endpoints" ""
}
export -f config::get_etcd_external_endpoints

#######################################
# 获取外部etcd endpoints 列表（空格分隔）
#######################################
config::get_etcd_external_endpoints_list() {
  local endpoints
  endpoints="$(config::get_etcd_external_endpoints)"
  endpoints="${endpoints//,/ }"
  local out="" item
  for item in ${endpoints}; do
    item="$(echo "${item}" | xargs)"
    [[ -n "${item}" ]] && out+="${item} "
  done
  echo "${out}"
}
export -f config::get_etcd_external_endpoints_list

#######################################
# 获取外部etcd endpoints 主机列表（空格分隔）
#######################################
config::get_etcd_external_endpoints_hosts() {
  local out="" endpoint host
  for endpoint in $(config::get_etcd_external_endpoints_list); do
    host="$(echo "${endpoint}" | sed -E 's#^[a-zA-Z]+://##' | cut -d/ -f1)"
    host="${host%%:*}"
    [[ -n "${host}" ]] && out+="${host} "
  done
  echo "${out}"
}
export -f config::get_etcd_external_endpoints_hosts

#######################################
# 获取主机地址（多集群并发安全）
# 优先从 cluster-scoped context 读取，回退到全局数组
#######################################
config::get_host_address() {
  local host_name="$1"

  # 优先：从 cluster-scoped context 读取
  local ctx_value
  if ctx_value="$(context::cluster::get_host "${host_name}.address" 2>/dev/null)" && [[ -n "${ctx_value}" ]]; then
    echo "${ctx_value}"
    return 0
  fi

  # 回退：全局数组
  if [[ -n "${KUBEXM_HOSTS[${host_name}.address]:-}" ]]; then
    echo "${KUBEXM_HOSTS[${host_name}.address]}"
    return 0
  fi

  # 未找到时返回空字符串，由调用方决定如何处理
  echo ""
  return 1
}
export -f config::get_host_address

#######################################
# 获取容器运行时类型
#######################################
config::get_runtime_type() {
  config::get "spec.runtime.type" "containerd"
}
export -f config::get_runtime_type

#######################################
# 获取容器运行时版本
#######################################
config::get_runtime_version() {
  config::get "spec.runtime.version" "$(defaults::get_containerd_version)"
}
export -f config::get_runtime_version

#######################################
# 获取CNI插件类型
#######################################
config::get_network_plugin() {
  config::get "spec.network.plugin" "calico"
}
export -f config::get_network_plugin

#######################################
# 获取网络接口
# 返回空字符串表示自动检测主网络接口
#######################################
config::get_network_interface() {
  config::get "spec.network.interface" ""
}
export -f config::get_network_interface

#######################################
# 获取负载均衡器是否启用
#######################################
config::get_loadbalancer_enabled() {
  config::getters::get_loadbalancer_enabled
}
export -f config::get_loadbalancer_enabled

#######################################
# 获取负载均衡器模式
#######################################
config::get_loadbalancer_mode() {
  config::getters::get_loadbalancer_mode
}
export -f config::get_loadbalancer_mode

#######################################
# 获取负载均衡器类型
#######################################
config::get_loadbalancer_type() {
  config::getters::get_loadbalancer_type
}
export -f config::get_loadbalancer_type

#######################################
# 获取VIP地址
#######################################
config::get_vip_address() {
  config::get "spec.loadbalancer.vip" ""
}
export -f config::get_vip_address

#######################################
# 获取VIP地址（兼容旧函数名）
#######################################
config::get_loadbalancer_vip() {
  config::get_vip_address
}
export -f config::get_loadbalancer_vip

#######################################
# 获取kube-vip部署模式（static-pod/daemon-set）
#######################################
config::get_loadbalancer_deploy_mode() {
  config::get "spec.loadbalancer.deploy_mode" "static-pod"
}
export -f config::get_loadbalancer_deploy_mode

#######################################
# 获取网络接口绑定
#######################################
config::get_loadbalancer_interface() {
  config::get "spec.loadbalancer.interface" "eth0"
}
export -f config::get_loadbalancer_interface

#######################################
# 获取metrics-server是否启用
#######################################
config::get_metrics_server_enabled() {
  config::get "spec.addons.metrics_server.enabled" "false"
}
export -f config::get_metrics_server_enabled

#######################################
# 获取nodelocaldns是否启用
#######################################
config::get_nodelocaldns_enabled() {
  config::get "spec.addons.nodelocaldns.enabled" "$(defaults::get_nodelocaldns_enabled)"
}
export -f config::get_nodelocaldns_enabled

#######################################
# 获取ingress controller是否启用
#######################################
config::get_ingress_enabled() {
  config::get "spec.addons.ingress_controller.enabled" "false"
}
export -f config::get_ingress_enabled

#######################################
# 获取ingress controller类型
#######################################
config::get_ingress_type() {
  config::get "spec.addons.ingress_controller.type" "nginx"
}
export -f config::get_ingress_type

#######################################
# 获取Registry是否启用
#######################################
config::get_registry_enabled() {
  config::get "spec.registry.enable" "false"
}
export -f config::get_registry_enabled

#######################################
# 获取Registry主机
# 如果配置为空，自动使用第一个 registry 角色节点的 IP
#######################################
config::get_registry_host() {
  local host
  host=$(config::get "spec.registry.host" "")
  
  # 如果 host 为空，尝试从 registry 角色组获取第一个节点的 IP
  if [[ -z "${host}" ]]; then
    local registry_members
    registry_members=$(config::get_role_members "registry")
    if [[ -n "${registry_members}" ]]; then
      local first_registry
      first_registry=$(echo "${registry_members}" | head -n1 | awk '{print $1}')
      if [[ -n "${first_registry}" ]]; then
        host=$(config::get_host_param "${first_registry}" "address")
      fi
    fi
  fi
  
  echo "${host}"
}
export -f config::get_registry_host

#######################################
# 获取Registry端口
#######################################
config::get_registry_port() {
  config::get "spec.registry.port" "5000"
}
export -f config::get_registry_port

#######################################
# 获取Registry数据目录
#######################################
config::get_registry_data_dir() {
  config::get "spec.registry.data_dir" "/var/lib/registry"
}
export -f config::get_registry_data_dir

#######################################
# 获取工作目录
#######################################
config::get_work_dir() {
  config::get "spec.paths.work_dir" "/tmp/kubexm"
}
export -f config::get_work_dir

#######################################
# 获取缓存目录
#######################################
config::get_cache_dir() {
  config::get "spec.paths.cache_dir" "/var/cache/kubexm"
}
export -f config::get_cache_dir

#######################################
# 获取下载并发数
#######################################
config::get_download_concurrency() {
  config::get "spec.advanced.download.concurrency" "5"
}
export -f config::get_download_concurrency

#######################################
# 获取下载重试次数
#######################################
config::get_download_retry() {
  config::get "spec.advanced.download.retry" "3"
}
export -f config::get_download_retry

#######################################
# 获取下载超时时间
#######################################
config::get_download_timeout() {
  config::get "spec.advanced.download.timeout" "300"
}
export -f config::get_download_timeout

#######################################
# 获取部署并发节点数
#######################################
config::get_deploy_parallel_nodes() {
  config::get "spec.advanced.deploy.parallel_nodes" "3"
}
export -f config::get_deploy_parallel_nodes

#######################################
# 获取健康检查重试次数
#######################################
config::get_health_check_retries() {
  config::get "spec.advanced.deploy.health_check_retries" "30"
}
export -f config::get_health_check_retries

#######################################
# 获取镜像预拉取是否启用
#######################################
config::get_image_pull_enabled() {
  config::get "spec.advanced.image_pull.enabled" "true"
}
export -f config::get_image_pull_enabled

#######################################
# 获取镜像预拉取并发数
#######################################
config::get_image_pull_parallel() {
  config::get "spec.advanced.image_pull.parallel" "3"
}
export -f config::get_image_pull_parallel

#######################################
# 获取证书有效期（天）
#######################################
config::get_cert_validity_days() {
  config::get "spec.certificates.validity_days" "3650"
}
export -f config::get_cert_validity_days

#######################################
# 获取证书自动续期是否启用
#######################################
config::get_cert_auto_renew_enabled() {
  config::get "spec.certificates.auto_renew.enabled" "true"
}
export -f config::get_cert_auto_renew_enabled

#######################################
# 获取证书续期提前天数
#######################################
config::get_cert_renew_days_before_expiry() {
  config::get "spec.certificates.auto_renew.days_before_expiry" "30"
}
export -f config::get_cert_renew_days_before_expiry

#######################################
# 获取日志级别
#######################################
config::get_log_level() {
  config::get "spec.logging.level" "info"
}
export -f config::get_log_level

#######################################
# 获取日志目录
#######################################
config::get_log_dir() {
  config::get "spec.logging.log_dir" "/var/log/kubexm"
}
export -f config::get_log_dir

#######################################
# 获取日志保留天数
#######################################
config::get_log_retention_days() {
  config::get "spec.logging.retention_days" "30"
}
export -f config::get_log_retention_days

#######################################
# 离线构建配置
#######################################

# 获取离线构建启用状态
config::get_offline_enabled() {
  config::get "spec.offline.enabled" "false"
}
export -f config::get_offline_enabled

# 获取离线构建OS列表
config::get_offline_os_list() {
  config::get "spec.offline.os_list" "centos7,rocky9,almalinux9,ubuntu22,debian12"
}
export -f config::get_offline_os_list

# 获取离线构建架构列表
config::get_offline_arch_list() {
  config::get "spec.offline.arch_list" "$(config::get_arch_list)"
}
export -f config::get_offline_arch_list

# 获取ISO卷标
config::get_iso_label() {
  local k8s_version=$(config::get_kubernetes_version)
  config::get "spec.offline.iso_label" "KUBEXM-${k8s_version//./}"
}
export -f config::get_iso_label

# 获取自定义包列表
config::get_custom_package_list() {
  config::get "spec.offline.custom_packages" ""
}
export -f config::get_custom_package_list

# 获取包构建并行数
config::get_offline_build_parallel() {
  config::get "spec.offline.build_parallel" "4"
}
export -f config::get_offline_build_parallel

# 获取Docker构建缓存设置
config::get_offline_docker_build_cache() {
  config::get "spec.offline.docker_build_cache" "true"
}
export -f config::get_offline_docker_build_cache

# 获取ISO生成超时时间（秒）
config::get_offline_iso_timeout() {
  config::get "spec.offline.iso_timeout" "3600"
}
export -f config::get_offline_iso_timeout

# 获取ISO校验和验证启用状态
config::get_offline_iso_verify() {
  config::get "spec.offline.iso_verify" "true"
}
export -f config::get_offline_iso_verify

# 获取离线安装自动重启设置
config::get_offline_install_reboot() {
  config::get "spec.offline.install_reboot" "false"
}
export -f config::get_offline_install_reboot

# 获取离线安装日志路径
config::get_offline_install_log() {
  config::get "spec.offline.install_log" "/var/log/kubexm-install.log"
}
export -f config::get_offline_install_log

# 获取离线包缓存目录
config::get_offline_package_cache_dir() {
  config::get "spec.offline.package_cache_dir" "$(config::get_cache_dir)/packages"
}
export -f config::get_offline_package_cache_dir

# 获取离线ISO输出目录
config::get_offline_iso_output_dir() {
  config::get "spec.offline.iso_output_dir" "$(config::get_work_dir)/iso"
}
export -f config::get_offline_iso_output_dir

# 获取离线构建工作目录
config::get_offline_work_dir() {
  config::get "spec.offline.work_dir" "$(config::get_work_dir)/offline"
}
export -f config::get_offline_work_dir

# 获取离线ISO压缩设置
config::get_offline_iso_compress() {
  config::get "spec.offline.iso_compress" "false"
}
export -f config::get_offline_iso_compress

# 获取离线构建清理设置
config::get_offline_build_cleanup() {
  config::get "spec.offline.build_cleanup" "false"
}
export -f config::get_offline_build_cleanup

# 获取离线安装后验证设置
config::get_offline_post_install_verify() {
  config::get "spec.offline.post_install_verify" "true"
}
export -f config::get_offline_post_install_verify

# 获取离线安装自动脚本生成设置
config::get_offline_auto_install_script() {
  config::get "spec.offline.auto_install_script" "true"
}
export -f config::get_offline_auto_install_script

# 获取离线安装说明文档生成设置
config::get_offline_generate_docs() {
  config::get "spec.offline.generate_docs" "true"
}
export -f config::get_offline_generate_docs

# 获取离线构建场景列表
config::get_offline_scenario_list() {
  local scenarios=()

  # 根据配置生成场景列表
  local k8s_type=$(config::get_kubernetes_type)
  local etcd_type=$(config::get_etcd_type)
  local lb_mode=$(config::get_loadbalancer_mode)
  local lb_type=$(config::get_loadbalancer_type)

  # 生成场景组合
  for k8s in "${k8s_type}" "kubeadm"; do
    for etcd in "${etcd_type}" "kubeadm"; do
      for lb_m in "${lb_mode}" "none" "internal" "external" "kube-vip"; do
        local scenario="${k8s}-${etcd}-${lb_m}-${lb_type}"
        scenarios+=("${scenario}")
      done
    done
  done

  printf '%s\n' "${scenarios[@]}" | sort -u | tr '\n' ','
}
export -f config::get_offline_scenario_list

#######################################
# 输出配置摘要信息（供所有命令使用）
#######################################
config::show_summary() {
  local k8s_version=$(config::get_kubernetes_version)
  local k8s_type=$(config::get_kubernetes_type)
  local etcd_type=$(config::get_etcd_type)
  local runtime_type=$(config::get_runtime_type)
  local network_plugin=$(config::get_network_plugin)
  local arch=$(config::get_arch_list)
  local lb_enabled=$(config::get_loadbalancer_enabled)
  local lb_mode=$(config::get_loadbalancer_mode)
  local lb_type=$(config::get_loadbalancer_type)

  log::info "Kubernetes版本: $k8s_version"
  log::info "部署类型: $k8s_type"
  log::info "Etcd类型: $etcd_type"
  log::info "容器运行时: $runtime_type"
  log::info "CNI插件: $network_plugin"
  log::info "架构: $arch"
  log::info "负载均衡: ${lb_enabled}/${lb_mode}/${lb_type}"
}
export -f config::show_summary

#######################################
# 校验配置联动一致性
# 确保 config.yaml 和 host.yaml 的配置正确对应
# Returns:
#   0 - 校验通过
#   1 - 校验失败
# Outputs:
#   错误信息到stderr
#######################################
config::validate_consistency() {
  config::validator::validate_consistency
}
export -f config::validate_consistency
