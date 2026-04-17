#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: os_sync_time
# 强制同步时间
# ==============================================================================


step::os.sync.time::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::os.sync.time "$@"
}

step::os.sync.time() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=os.sync_time] Syncing time..."

  # 强制同步时间
  if command -v chronyc &>/dev/null; then
    chronyc -a makestep || true
  fi

  # 使用 ntpdate 强制同步（如果可用）
  if command -v ntpdate &>/dev/null; then
    ntpdate -b pool.ntp.org || logger::warn "[host=${host}] NTP sync failed"
  fi

  # 使用 systemctl 强制同步
  if command -v timedatectl &>/dev/null; then
    timedatectl set-ntp true || true
  fi

  logger::info "[host=${host} step=os.sync_time] Time synced"
  return 0
}

step::os.sync.time::check() {
  return 1  # 总是执行，确保时间一致
}

step::os.sync.time::rollback() { return 0; }

step::os.sync.time::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_roles
}
