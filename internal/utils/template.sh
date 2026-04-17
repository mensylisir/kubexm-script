#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Enhanced Template Engine
# ==============================================================================
# 支持 envsubst 和 Go 模板两种渲染方式
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载日志模块
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"

# 渲染器路径
GO_TEMPLATE_RENDERER="${KUBEXM_ROOT:-${KUBEXM_SCRIPT_ROOT}}/bin/xmrender"

#######################################
# 检测模板类型
#######################################
template::detect_type() {
  local template_file="$1"

  if [[ ! -f "${template_file}" ]]; then
    echo "unknown"
    return 1
  fi

  # 检查是否包含Go模板语法
  if grep -q '{{-' "${template_file}" || grep -q '{{ .' "${template_file}"; then
    echo "go"
    return 0
  fi

  # 检查是否包含envsubst语法
  if grep -q '\${' "${template_file}"; then
    echo "envsubst"
    return 0
  fi

  # 默认使用envsubst
  echo "envsubst"
}

#######################################
# 渲染Go模板
#######################################
template::render_go() {
  local template_file="$1"
  local output_file="$2"
  local data_file="${3:-}"

  if [[ ! -f "${template_file}" ]]; then
    log::error "Template file not found: ${template_file}"
    return 1
  fi

  log::debug "Rendering Go template: ${template_file} -> ${output_file}"

  # 检查渲染器是否存在
  if [[ ! -x "${GO_TEMPLATE_RENDERER}" ]]; then
    log::error "Go template renderer not found: ${GO_TEMPLATE_RENDERER}"
    return 1
  fi

  # 创建输出目录
  local output_dir
  output_dir=$(dirname "${output_file}")
  mkdir -p "${output_dir}"

  # 渲染模板
  if "${GO_TEMPLATE_RENDERER}" "${template_file}" "${output_file}" "${data_file}"; then
    log::success "Go template rendered: ${output_file}"
    return 0
  else
    log::error "Failed to render Go template: ${template_file}"
    return 1
  fi
}

#######################################
# 渲染envsubst模板
#######################################
template::render_envsubst() {
  local template_file="$1"
  local output_file="$2"
  local vars_name="${3:-}"

  if [[ ! -f "${template_file}" ]]; then
    log::error "Template file not found: ${template_file}"
    return 1
  fi

  log::debug "Rendering envsubst template: ${template_file} -> ${output_file}"

  # 如果提供了变量名,通过nameref导出到环境
  if [[ -n "${vars_name}" ]]; then
    local -n vars_ref="${vars_name}"
    if [[ ${#vars_ref[@]} -gt 0 ]]; then
      for key in "${!vars_ref[@]}"; do
        export "${key}=${vars_ref[$key]}"
      done
    fi
  fi

  # 创建输出目录
  local output_dir
  output_dir=$(dirname "${output_file}")
  mkdir -p "${output_dir}"

  # 渲染模板
  if envsubst < "${template_file}" > "${output_file}"; then
    log::success "envsubst template rendered: ${output_file}"
    return 0
  else
    log::error "Failed to render envsubst template: ${template_file}"
    return 1
  fi
}

#######################################
# 渲染模板文件（统一版本，支持输出到文件或stdout）
# Arguments:
#   $1 - 模板文件路径
#   $2 - 输出文件路径（"-" 表示输出到 stdout）
#   $3 - 变量名（可选，数组变量名）或 key=value 格式变量
#   $4 - 数据文件路径（可选，JSON格式，用于go模板）
# Returns:
#   渲染后的内容或文件
#######################################
template::render() {
  local template_file="$1"
  local output_file="$2"
  local vars_or_value="${3:-}"
  local data_file="${4:-}"

  if [[ ! -f "${template_file}" ]]; then
    log::error "Template file not found: ${template_file}"
    return 1
  fi

  # 检测模板类型
  local tmpl_type
  tmpl_type=$(template::detect_type "${template_file}")

  # 渲染并输出
  case "${tmpl_type}" in
    go)
      # Go模板使用数据文件
      template::render_go "${template_file}" "${output_file}" "${data_file}"
      ;;
    envsubst)
      # envsubst模板支持 vars_name 数组或 key=value 格式
      if [[ -n "${vars_or_value}" && "${vars_or_value}" == *"="* ]]; then
        # key=value 格式：创建临时变量数组
        local -a var_array=("${vars_or_value}")
        template::render_envsubst "${template_file}" "${output_file}" var_array
      else
        # 变量名格式
        template::render_envsubst "${template_file}" "${output_file}" "${vars_or_value}"
      fi
      ;;
    *)
      log::error "Unknown template type: ${template_file}"
      return 1
      ;;
  esac
}

#######################################
# 使用变量列表渲染模板
#######################################
template::render_with_vars() {
  local template_file="$1"
  local output_file="$2"
  shift 2

  if [[ ! -f "${template_file}" ]]; then
    log::error "Template file not found: ${template_file}"
    return 1
  fi

  log::debug "Rendering template with vars: ${template_file}"

  # 导出所有变量
  local -A var_array
  for var in "$@"; do
    if [[ "$var" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"
      var_array["${key}"]="${value}"
      export "${key}=${value}"
      log::debug "  ${key}=${value}"
    fi
  done

  # 渲染模板
  template::render "${template_file}" "${output_file}" var_array
}

#######################################
# 批量渲染目录中的模板
#######################################
template::render_dir() {
  local template_dir="$1"
  local output_dir="$2"
  local vars_name="${3:-}"
  local data_file="${4:-}"

  if [[ ! -d "${template_dir}" ]]; then
    log::error "Template directory not found: ${template_dir}"
    return 1
  fi

  log::info "Rendering templates from: ${template_dir} to ${output_dir}"

  local errors=0
  local total=0

  # 查找所有 .tmpl 文件
  while IFS= read -r -d '' template_file; do
    ((total++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    # 计算相对路径
    local rel_path="${template_file#${template_dir}/}"

    # 去除 .tmpl 后缀
    local output_path="${output_dir}/${rel_path%.tmpl}"

    # 渲染模板
    if ! template::render "${template_file}" "${output_path}" "${vars_name}" "${data_file}"; then
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done < <(find "${template_dir}" -name "*.tmpl" -type f -print0)

  log::info "Rendered ${total} templates, ${errors} failed"

  if [[ $errors -gt 0 ]]; then
    log::error "Failed to render ${errors} template(s)"
    return 1
  fi

  log::success "All templates rendered successfully"
  return 0
}

#######################################
# 验证渲染后的文件
#######################################
template::validate() {
  local file_path="$1"
  local validation_cmd="${2:-}"

  if [[ ! -f "${file_path}" ]]; then
    log::error "File not found: ${file_path}"
    return 1
  fi

  # 检查是否包含未替换的变量
  if grep -qE '\$\{|\{\{' "${file_path}"; then
    log::warn "File contains unreplaced variables: ${file_path}"
    grep -nE '\$\{|\{\{' "${file_path}" | head -n 5
  fi

  # 如果提供了验证命令,执行它
  if [[ -n "${validation_cmd}" ]]; then
    log::debug "Validating with: ${validation_cmd}"
    if ${validation_cmd} "${file_path}"; then
      log::success "Validation passed: ${file_path}"
      return 0
    else
      log::error "Validation failed: ${file_path}"
      return 1
    fi
  fi

  return 0
}

#######################################
# 获取模板文件路径
#######################################
template::get_path() {
  local template_name="$1"
  echo "${KUBEXM_SCRIPT_ROOT}/templates/${template_name}"
}

# 导出所有函数
export -f template::detect_type
export -f template::render_go
export -f template::render_envsubst
export -f template::render
export -f template::render_with_vars
export -f template::render_dir
export -f template::validate
export -f template::get_path
