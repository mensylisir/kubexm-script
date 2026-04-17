#!/usr/bin/env bash
set -euo pipefail

step::images.push.collect.packages.list::check() { return 1; }

step::images.push.collect.packages.list::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local push_from_packages
  push_from_packages="$(context::get "images_push_from_packages" || true)"
  if [[ "${push_from_packages}" != "true" ]]; then
    return 0
  fi

  local packages_dir
  packages_dir="$(context::get "images_push_packages_dir" || true)"
  log::info "从packages目录推送镜像: $packages_dir"

  if [[ ! -d "${packages_dir}" ]]; then
    log::error "packages目录不存在: ${packages_dir}"
    return 1
  fi

  local list_file="${packages_dir}/images.list"
  if [[ ! -f "${list_file}" && -f "${packages_dir}/images/images.list" ]]; then
    packages_dir="${packages_dir}/images"
    list_file="${packages_dir}/images.list"
  elif [[ ! -f "${list_file}" && -f "$(dirname "${packages_dir}")/images.list" ]]; then
    packages_dir="$(dirname "${packages_dir}")"
    list_file="${packages_dir}/images.list"
  fi

  if [[ ! -f "${list_file}" ]]; then
    log::error "未找到镜像清单: ${list_file}"
    log::info "请先执行 kubexm download --cluster=... 并将 packages 目录带到离线环境"
    return 1
  fi

  context::set "images_push_packages_dir" "${packages_dir}"

  local items=""
  local total_images=0
  local missing=0
  local image
  while IFS= read -r image; do
    [[ -z "${image}" ]] && continue
    [[ "${image}" =~ ^# ]] && continue

    local image_name
    image_name=$(echo "${image}" | tr '/' '_' | tr ':' '_')
    local image_dir="${packages_dir}/${image_name}"

    if [[ ! -f "${image_dir}/manifest.json" && ! -f "${image_dir}/oci-layout" ]]; then
      log::error "镜像目录缺失: ${image_dir}"
      missing=1
      continue
    fi

    items+="${image}|${image_dir}"$'\n'
    ((total_images++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  done < "${list_file}"

  if [[ "${missing}" -ne 0 ]]; then
    log::error "镜像包不完整，请确认 packages/images 内容完整"
    return 1
  fi

  if [[ "${total_images}" -eq 0 ]]; then
    log::error "镜像清单为空: ${list_file}"
    return 1
  fi

  log::info "找到 $total_images 个镜像"
  context::set "images_push_packages_items" "${items}"
  context::set "images_push_packages_total" "${total_images}"
}

step::images.push.collect.packages.list::rollback() { return 0; }

step::images.push.collect.packages.list::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
