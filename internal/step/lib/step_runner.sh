#!/usr/bin/env bash
set -euo pipefail

# Run a sequence of steps with shared args.
# Usage: step::run_steps <ctx> <arg1> ... <argN> -- <step1> <step2> ...
# Step format: name:path (path optional if already registered)

step::run_steps() {
  local ctx="$1"
  shift

  local args=()
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then
      shift
      break
    fi
    args+=("$1")
    shift
  done

  if [[ $# -eq 0 ]]; then
    echo "no steps provided" >&2
    return 2
  fi

  local entry name path hosts host
  for entry in "$@"; do
    if [[ "$entry" == *":"* ]]; then
      name="${entry%%:*}"
      path="${entry#*:}"
      if [[ -n "$path" ]]; then
        step::register "$name" "$path"
      fi
    else
      name="$entry"
    fi

    step::load "$name"
    hosts="$(step::${name}::targets "${ctx}" "${args[@]}")" || return 1
    # Split on newlines only (hostnames shouldn't contain newlines but may contain spaces)
    local IFS=$'\n'
    for host in ${hosts}; do
      runner::exec "$name" "${ctx}" "${host}" "${args[@]}"
    done
  done
}

export -f step::run_steps
