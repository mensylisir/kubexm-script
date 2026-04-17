#!/usr/bin/env bash
set -euo pipefail

step::images.push.packages.concurrent.exec::check() { return 1; }

step::images.push.packages.concurrent.exec::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local skip
  skip="$(context::get "images_push_concurrent_skip" || echo "false")"
  if [[ "${skip}" == "true" ]]; then
    return 0
  fi

  local target_registry max_parallel items log_dir
  target_registry="$(context::get "images_push_target_registry" || true)"
  max_parallel="$(context::get "images_push_max_parallel" || echo "5")"
  items="$(context::get "images_push_packages_items" || true)"
  log_dir="$(context::get "images_push_concurrent_log_dir" || true)"

  echo "$items" | xargs -P "$max_parallel" -I {} bash -c '
    item="$1"
    target_registry="$2"
    log_dir="$3"

    image="${item%%|*}"
    image_dir="${item#*|}"

    image_path="$image"
    if [[ "$image" == */* ]]; then
      first="${image%%/*}"
      if [[ "$first" == *.* || "$first" == *:* || "$first" == "localhost" ]]; then
        image_path="${image#*/}"
      fi
    fi

    transport="oci"
    if [[ -f "${image_dir}/manifest.json" && ! -f "${image_dir}/oci-layout" && ! -f "${image_dir}/index.json" ]]; then
      transport="dir"
    fi

    safe_name="$(echo "$image" | tr "/" "_" | tr ":" "_")"
    target_image="$target_registry/$image_path"
    log_file="$log_dir/${safe_name}.log"

    if skopeo copy --retry-times=3 --dest-tls-verify=false "${transport}:${image_dir}" "docker://${target_image}" > "$log_file" 2>&1; then
      echo "SUCCESS:${image}" >> "$log_dir/results.txt"
    else
      echo "FAILED:${image}" >> "$log_dir/results.txt"
    fi
  ' _ {} "$target_registry" "$log_dir"
}

step::images.push.packages.concurrent.exec::rollback() { return 0; }

step::images.push.packages.concurrent.exec::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
