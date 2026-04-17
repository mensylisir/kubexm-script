#!/usr/bin/env bash
#
# lint-step-structure.sh - Step 结构完整性检测
# ==============================================================================

ROOT_DIR="${KUBEXM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STEP_DIR="${ROOT_DIR}/internal/step"
CONTEXT_FILE="${ROOT_DIR}/internal/context/context.sh"

ERRORS=0
WARNINGS=0

error() { echo "ERROR: $*" >&2; ERRORS=$((ERRORS+1)); }
warn()  { echo "WARNING: $*" >&2; WARNINGS=$((WARNINGS+1)); }

# 预加载 context.sh 中的函数名
CTX_FUNC_PATTERN=$(grep -oE '^context::[a-z_]+(\.[a-z_]+)?\s*\(\)' "${CONTEXT_FILE}" 2>/dev/null | \
  sed 's/\s*().*//' | tr '\n' '|' | sed 's/|$//')

contains_match() {
  local file="$1"
  local pattern="$2"
  grep -qE "${pattern}" "${file}" 2>/dev/null
}

check_boundary() {
  local file="$1"
  local source_pattern="$2"
  local call_pattern="$3"
  local source_error="$4"
  local call_error="$5"

  if contains_match "${file}" "${source_pattern}"; then
    error "${file}: ${source_error}"
  fi
  if contains_match "${file}" "${call_pattern}"; then
    error "${file}: ${call_error}"
  fi
}

check_layer_boundaries() {
  local file="$1"

  case "${file}" in
    "${ROOT_DIR}/bin/"*)
      # Entry point: must only source pipeline, not module/task/step directly
      check_boundary "${file}" \
        'source.*internal/(module|task|step|runner|connector)/' \
        '(module::|task::|step::)' \
        'bin entry point sources lower layer (must only source pipeline)' \
        'bin entry point calls lower layer function (must only call pipeline)'
      ;;
    "${ROOT_DIR}/internal/pipeline/"*.sh|"${ROOT_DIR}/internal/pipeline/"*/*.sh)
      # Pipeline may source task/ files for cross-component orchestration functions
      # (task/common/ for health/scale/smoke_test, task/kubeadm/ for remove, etc.)
      # These are step compositions, not lower-layer implementation details
      if contains_match "${file}" 'source.*internal/task/.*\.sh'; then
        local allowed=0
        # task/common.sh - main module with scale, health, update_lb, drain helpers
        contains_match "${file}" 'source.*internal/task/common\.sh' && allowed=1
        # task/common/ - scale, smoke_test, health, certs, config, ntp tasks
        contains_match "${file}" 'source.*internal/task/common/' && allowed=1
        # task/health/ - health check tasks
        contains_match "${file}" 'source.*internal/task/health/' && allowed=1
        # task/certs/ - certificate tasks
        contains_match "${file}" 'source.*internal/task/certs/' && allowed=1
        # task/kubeadm/remove.sh - kubelet/kubeadm reset for delete
        contains_match "${file}" 'source.*internal/task/kubeadm/remove\.sh' && allowed=1
        # task/hosts/cleanup.sh - hosts cleanup for delete
        contains_match "${file}" 'source.*internal/task/hosts/cleanup\.sh' && allowed=1
        # task/etcd/ - etcd backup/upgrade tasks
        contains_match "${file}" 'source.*internal/task/etcd/' && allowed=1
        # task/addons/ - addon tasks
        contains_match "${file}" 'source.*internal/task/addons/' && allowed=1
        if [[ ${allowed} -eq 0 ]]; then
          error "${file}: pipeline sources non-module internal layer"
        fi
      fi
      if contains_match "${file}" 'source.*internal/(step|runner|connector)/.*\.sh'; then
        error "${file}: pipeline sources step/runner/connector layer"
      fi
      # Pipeline may not call step/runner/connector functions directly
      if contains_match "${file}" '(step::|runner::|connector::|ssh::)'; then
        error "${file}: pipeline calls step/runner/connector function (must use module layer)"
      fi
      ;;
    "${ROOT_DIR}/internal/module/"*.sh)
      check_boundary "${file}" \
        'source.*internal/(step|runner|connector)/.*\.sh' \
        '(step::|runner::|connector::|ssh::)' \
        'module sources lower internal layer directly' \
        'module calls lower internal layer directly'
      ;;
    "${ROOT_DIR}/internal/task/"*.sh)
      check_boundary "${file}" \
        'source.*internal/(runner|connector)/.*\.sh' \
        '(runner::|connector::|ssh::)' \
        'task sources runner/connector directly' \
        'task calls runner/connector directly'
      ;;
    "${ROOT_DIR}/internal/step/"*.sh)
      check_boundary "${file}" \
        'source.*internal/task/.*\.sh' \
        '(connector::|ssh::)' \
        'step sources task layer directly' \
        'step calls connector::/ssh:: (must use runner::)'
      if contains_match "${file}" 'source.*(connector|ssh)\.sh'; then
        error "${file}: sources connector/ssh.sh (must use runner.sh)"
      fi
      ;;
    "${ROOT_DIR}/internal/runner/"*.sh)
      check_boundary "${file}" \
        'source.*internal/(pipeline|module|task|step)/.*\.sh' \
        '(pipeline::|module::|task::)' \
        'runner sources upper internal layer' \
        'runner calls upper internal layer'
      ;;
  esac
}

main() {
  echo "=== Step Structure Lint ==="
  echo "Step dir: ${STEP_DIR}"

  local count=0

  # Scan step/ layer files only (not task/, module/, etc.)
  while IFS= read -r file; do
    count=$((count + 1))
    check_layer_boundaries "${file}"
    check_file "${file}"
  done < <(find "${STEP_DIR}" -name '*.sh' -type f 2>/dev/null | sort)

  # Scan pipeline/ files for layer boundary violations
  while IFS= read -r file; do
    count=$((count + 1))
    check_layer_boundaries "${file}"
  done < <(find "${ROOT_DIR}/internal/pipeline" -name '*.sh' -type f 2>/dev/null | sort)

  # Scan bin/ entry point files (no .sh extension)
  if [[ -d "${ROOT_DIR}/bin" ]]; then
    for file in "${ROOT_DIR}"/bin/*; do
      [[ -f "${file}" && -x "${file}" ]] || continue
      # Skip if it's a binary/symlink, not a shell script
      if file "${file}" | grep -q 'shell script'; then
        count=$((count + 1))
        check_layer_boundaries "${file}"
      fi
    done
  fi

  echo ""
  echo "=== Results ==="
  echo "Files checked: ${count}"
  echo "Errors: ${ERRORS}"
  echo "Warnings: ${WARNINGS}"

  if [[ "${ERRORS}" -gt 0 ]]; then
    echo "FAILED: ${ERRORS} error(s) found"
    return 1
  fi
  if [[ "${WARNINGS}" -gt 0 ]]; then
    echo "PASSED with ${WARNINGS} warning(s)"
  else
    echo "PASSED: All checks passed"
  fi
  return 0
}

check_file() {
  local file="$1"
  local f

  case "${file}" in
    "${ROOT_DIR}/internal/step/"*.sh)
      ;;
    *)
      return 0
      ;;
  esac

  # context:: 函数必须存在
  for f in $(grep -oE 'context::[a-z_]+(\.[a-z_]+)?' "${file}" 2>/dev/null | \
    grep -vE '^context::(cluster::|get$|set$|cancel$|with$|init$|run_remote$|copy_to_remote$|copy_from_remote$|render_template$)' | \
    sort -u); do
    if ! echo "${CTX_FUNC_PATTERN}" | grep -qF "${f}"; then
      error "${file}: calls undefined context function '${f}'"
    fi
  done

  # step 函数存在性（grep 提取后 sed 已去掉 ()）
  local step_funcs
  step_funcs=$(grep -oE 'step::[a-z][a-z0-9._]*::[a-z]+\s*\(\)' "${file}" 2>/dev/null | \
    sed 's/\s*().*//' | sort -u)

  local has_any_step
  has_any_step=$(echo "${step_funcs}" | grep -cE '^step::' || true)
  [[ "${has_any_step}" -eq 0 ]] && return 0

  local has_run has_check has_rollback
  has_run=$(echo "${step_funcs}" | grep -cE '::run$' || true)
  has_check=$(echo "${step_funcs}" | grep -cE '::check$' || true)
  has_rollback=$(echo "${step_funcs}" | grep -cE '::rollback$' || true)

  [[ "${has_run}" -eq 0 ]] && error "${file}: missing ::run function"
  [[ "${has_check}" -eq 0 ]] && error "${file}: missing ::check function"
  [[ "${has_rollback}" -eq 0 ]] && warn "${file}: missing ::rollback function (recommended)"

  # ::check 空桩检查（排除闭合括号行）
  # 容忍有意图的 always-run 设计（有注释说明），仅报告无注释的真 stub
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "${line}" =~ ::check[[:space:]]*\(\) ]]; then
      local body stripped
      body=$(tail -n +$((line_num)) "${file}" | head -4)
      # 移除闭合括号后再检查
      stripped=$(echo "${body}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | grep -v '^[[:space:]]*}[[:space:]]*$' || true)
      if [[ $(echo "${stripped}" | wc -l || echo 0) -le 3 ]] && \
         echo "${stripped}" | grep -qE '^\s*return\s+([01])\s*;?\s*$'; then
        # 检查是否有注释说明（有意图的 always-run）
        if ! echo "${body}" | grep -v '^[[:space:]]*}[[:space:]]*$' | grep -qE '^\s*#'; then
          error "${file}: line ${line_num}: ::check is a stub (always return, no explanation)"
        fi
      fi
    fi
  done < "${file}"
}

main "$@"
