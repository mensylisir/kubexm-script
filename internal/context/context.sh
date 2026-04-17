#!/usr/bin/env bash
set -euo pipefail

declare -A KUBEXM_CONTEXT=()
KUBEXM_CONTEXT_DIR=""
KUBEXM_CLUSTER_CONTEXT_DIR=""

# ==============================================================================
# 集群隔离 Context (多集群并发支持)
# ==============================================================================
# 每个集群的配置、主机、角色组状态隔离存储在独立目录
# 路径: ${KUBEXM_DATA_DIR:-$PWD/.kubexm}/${CLUSTER_NAME}/
#   ├── config/      # KUBEXM_CONFIG 键值对 (spec.kubernetes.version 等)
#   ├── hosts/       # KUBEXM_HOSTS 键值对 (node1.address, node1.user 等)
#   └── roles/       # KUBEXM_ROLE_GROUPS 键值对 (control-plane, worker 等)
# KUBEXM_DATA_DIR 默认 PWD/.kubexm，允许通过环境变量覆盖
# ==============================================================================

# 集群 Context 目录根路径
context::cluster::root() {
  local cluster_name="${1:-${KUBEXM_CLUSTER_NAME:-default}}"
  local data_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}"
  echo "${data_dir}/${cluster_name}"
}

# 初始化集群 Context（创建目录结构）
context::cluster::init() {
  local cluster_name="${KUBEXM_CLUSTER_NAME-}"
  if [[ -z "${cluster_name}" ]]; then
    echo "Error: KUBEXM_CLUSTER_NAME is not set. Please specify --cluster=<name>" >&2
    return 1
  fi
  KUBEXM_CLUSTER_CONTEXT_DIR="$(context::cluster::root)"
  mkdir -p "${KUBEXM_CLUSTER_CONTEXT_DIR}/config"
  mkdir -p "${KUBEXM_CLUSTER_CONTEXT_DIR}/hosts"
  mkdir -p "${KUBEXM_CLUSTER_CONTEXT_DIR}/roles"
}

# 设置配置值（集群隔离）
# 用法: context::cluster::set_config <key> <value>
context::cluster::set_config() {
  local key="$1"; local value="$2"
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  # 安全检查：禁止路径穿越
  if [[ "${key}" == *"/"* || "${key}" == *".."* || -z "${key}" ]]; then
    return 2
  fi
  printf '%s' "${value}" > "${KUBEXM_CLUSTER_CONTEXT_DIR}/config/${key}"
}

# 获取配置值（从当前集群 context 读取）
# 用法: context::cluster::get_config <key> [default]
context::cluster::get_config() {
  local key="$1"; local default="${2:-}"
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  local file="${KUBEXM_CLUSTER_CONTEXT_DIR}/config/${key}"
  if [[ -f "${file}" ]]; then
    cat "${file}"
    return 0
  fi
  echo "${default}"
  return 0
}

# 设置主机参数（集群隔离）
# 用法: context::cluster::set_host <host_key> <value>
# host_key 格式: node1.address, node1.user, node1.ssh_key 等
context::cluster::set_host() {
  local key="$1"; local value="$2"
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  if [[ "${key}" == *"/"* || "${key}" == *".."* || -z "${key}" ]]; then
    return 2
  fi
  printf '%s' "${value}" > "${KUBEXM_CLUSTER_CONTEXT_DIR}/hosts/${key}"
}

# 获取主机参数（从当前集群 context 读取）
# 用法: context::cluster::get_host <host_key> [default]
context::cluster::get_host() {
  local key="$1"; local default="${2:-}"
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  local file="${KUBEXM_CLUSTER_CONTEXT_DIR}/hosts/${key}"
  if [[ -f "${file}" ]]; then
    cat "${file}"
    return 0
  fi
  echo "${default}"
  return 0
}

# 设置角色组成员（集群隔离）
# 用法: context::cluster::set_role_group <role> <members>
# members 格式: "node1 node2 node3"（空格分隔）
context::cluster::set_role_group() {
  local role="$1"; local members="$2"
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  if [[ "${role}" == *"/"* || "${role}" == *".."* || -z "${role}" ]]; then
    return 2
  fi
  printf '%s' "${members}" > "${KUBEXM_CLUSTER_CONTEXT_DIR}/roles/${role}"
}

# 获取角色组成员（从当前集群 context 读取）
# 用法: context::cluster::get_role_group <role> [default]
context::cluster::get_role_group() {
  local role="$1"; local default="${2:-}"
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  local file="${KUBEXM_CLUSTER_CONTEXT_DIR}/roles/${role}"
  if [[ -f "${file}" ]]; then
    cat "${file}"
    return 0
  fi
  echo "${default}"
  return 0
}

# 切换到另一个集群的 context
# 用法: context::cluster::switch <cluster_name>
context::cluster::switch() {
  local new_cluster="$1"
  KUBEXM_CLUSTER_NAME="${new_cluster}"
  context::cluster::init
}

# 获取所有角色组名称
# 用法: context::cluster::list_role_groups
context::cluster::list_role_groups() {
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  if [[ -d "${KUBEXM_CLUSTER_CONTEXT_DIR}/roles" ]]; then
    ls "${KUBEXM_CLUSTER_CONTEXT_DIR}/roles/" 2>/dev/null || true
  fi
}

# 获取所有主机名（通过 hosts/ 目录中的 .address 文件）
# 用法: context::cluster::list_hosts
context::cluster::list_hosts() {
  : "${KUBEXM_CLUSTER_CONTEXT_DIR:?cluster context not initialized}"
  local dir="${KUBEXM_CLUSTER_CONTEXT_DIR}/hosts"
  if [[ -d "${dir}" ]]; then
    ls "${dir}/" 2>/dev/null | sed 's/\.address$//' | sort -u || true
  fi
}

# ==============================================================================
# 运行时 Context（单次执行状态，非集群隔离）
# ==============================================================================

context::init() {
  KUBEXM_RUN_ID="${KUBEXM_RUN_ID:-$(date +%s%N)}"
  KUBEXM_CONTEXT_DIR="/tmp/kubexm-context-${KUBEXM_RUN_ID}"
  mkdir -p "${KUBEXM_CONTEXT_DIR}"
}

context::set() {
  local key="$1" value="$2"
  context::_ensure_dir
  if [[ "${key}" == *"/"* || "${key}" == *".."* ]]; then
    return 2
  fi
  KUBEXM_CONTEXT["${key}"]="${value}"
  printf '%s' "${value}" > "${KUBEXM_CONTEXT_DIR}/${key}"
}

context::get() {
  local key="$1"
  if [[ -n "${KUBEXM_CONTEXT["${key}"]+x}" ]]; then
    printf '%s' "${KUBEXM_CONTEXT["${key}"]}"
    return 0
  fi
  context::_ensure_dir
  if [[ -f "${KUBEXM_CONTEXT_DIR}/${key}" ]]; then
    cat "${KUBEXM_CONTEXT_DIR}/${key}"
    return 0
  fi
  return 1
}

context::with() {
  local scope="$1" fn="$2"
  local cancelled
  cancelled="$(context::get "cancelled" || true)"
  if [[ "${cancelled}" == "true" ]]; then
    return 1
  fi
  "${fn}" "${scope}"
}

context::cancel() {
  context::set "cancelled" "true"
}

# ==============================================================================
# 兼容层：Step 层使用 context::run_remote，但实际调用 Runner 层
# 注意：Step 严禁直接调用 Connector，必须通过 Runner
# ==============================================================================

# 远程执行命令（兼容接口，内部调用 runner::remote_exec）
# 用法: context::run_remote <host> <cmd>
context::run_remote() {
  local host="$1"
  shift
  KUBEXM_HOST="${host}" runner::remote_exec "$@"
}

# 远程复制文件到远程主机（兼容接口）
# 用法: context::copy_to_remote <host> <src> <dest>
context::copy_to_remote() {
  local host="$1"
  local src="$2"
  local dest="$3"
  KUBEXM_HOST="${host}" runner::remote_copy_file "${src}" "${dest}"
}

# 远程复制文件从远程主机（兼容接口）
# 用法: context::copy_from_remote <host> <src> <dest>
context::copy_from_remote() {
  local host="$1"
  local src="$2"
  local dest="$3"
  KUBEXM_HOST="${host}" runner::remote_copy_from "${src}" "${dest}"
}

# ==============================================================================
# 模板渲染 + 远程分发（Step 层专用）
# ==============================================================================
# 用法: context::render_template <host> <template> <dest> [KEY=value ...]
# 1. 加载 template.sh 渲染模板
# 2. 通过 runner::remote_copy_file 分发到远程主机
# 注意：调用前必须已 source runner.sh
# ==============================================================================
context::render_template() {
  local host="$1"
  local template_file="$2"
  local dest="$3"
  shift 3
  local -a kv_pairs=("$@")

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  # 懒加载 template.sh（避免每次 source）
  if ! declare -f template::render_with_vars >/dev/null 2>&1; then
    source "${KUBEXM_ROOT}/internal/utils/template.sh"
  fi

  # 渲染到临时文件
  local tmp_dir="${KUBEXM_CONTEXT_DIR:-/tmp/kubexm-$$}"
  mkdir -p "${tmp_dir}"
  local tmp_file
  tmp_file=$(mktemp "${tmp_dir}/render-XXXXXX")

  # 导出所有 KEY=value 到环境（用于 envsubst）
  local kv
  for kv in "${kv_pairs[@]}"; do
    if [[ "${kv}" == *"="* ]]; then
      local key="${kv%%=*}"
      local value="${kv#*=}"
      export "${key}=${value}"
    fi
  done

  # 渲染：先尝试 Go 模板格式，再降级到 envsubst
  local rendered=0
  if grep -q '{{-' "${template_file}" 2>/dev/null || grep -q '{{ .' "${template_file}" 2>/dev/null; then
    if template::render_go "${template_file}" "${tmp_file}" "" 2>/dev/null; then
      rendered=1
    fi
  fi

  if [[ "${rendered}" -eq 0 ]]; then
    if ! template::render_with_vars "${template_file}" "${tmp_file}" "${kv_pairs[@]}" 2>/dev/null; then
      # 最终降级：简单 envsubst
      if ! envsubst < "${template_file}" > "${tmp_file}" 2>/dev/null; then
        cp "${template_file}" "${tmp_file}"
      fi
    fi
  fi

  # 复制到远程主机
  KUBEXM_HOST="${host}" runner::remote_copy_file "${tmp_file}" "${dest}"

  # 清理临时文件
  rm -f "${tmp_file}"
}

# ==============================================================================
# 导出集群隔离函数
# ==============================================================================
export -f context::cluster::root
export -f context::cluster::init
export -f context::cluster::set_config
export -f context::cluster::get_config
export -f context::cluster::set_host
export -f context::cluster::get_host
export -f context::cluster::set_role_group
export -f context::cluster::get_role_group
export -f context::cluster::switch
export -f context::cluster::list_role_groups
export -f context::cluster::list_hosts

export -f context::run_remote
export -f context::copy_to_remote
export -f context::copy_from_remote
export -f context::render_template
