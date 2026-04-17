#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certs Task - Certificate Renew
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/certs/restart_kubernetes.sh"
source "${KUBEXM_ROOT}/internal/task/certs/restart_etcd.sh"

# -----------------------------------------------------------------------------
# 续期 Kubernetes CA
# -----------------------------------------------------------------------------
task::renew_kubernetes_ca() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "certs.backup.before.renew:${KUBEXM_ROOT}/internal/step/certs/kubeadm/backup_certs_before_renew.sh" \
    "certs.renew.kubernetes.ca:${KUBEXM_ROOT}/internal/step/certs/kubeadm/renew_kubernetes_ca.sh"
}

# -----------------------------------------------------------------------------
# 续期 etcd CA
# -----------------------------------------------------------------------------
task::renew_etcd_ca() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "certs.backup.before.renew:${KUBEXM_ROOT}/internal/step/certs/kubeadm/backup_certs_before_renew.sh" \
    "certs.renew.etcd.ca:${KUBEXM_ROOT}/internal/step/certs/etcd/renew_etcd_ca.sh"
}

# -----------------------------------------------------------------------------
# 续期 Kubernetes 叶子证书
# -----------------------------------------------------------------------------
task::renew_kubernetes_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "certs.backup.before.renew:${KUBEXM_ROOT}/internal/step/certs/kubeadm/backup_certs_before_renew.sh" \
    "certs.renew.kubernetes.certs:${KUBEXM_ROOT}/internal/step/certs/kubeadm/renew_kubernetes_certs.sh"
}

# -----------------------------------------------------------------------------
# 续期 etcd 叶子证书
# -----------------------------------------------------------------------------
task::renew_etcd_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "certs.backup.before.renew:${KUBEXM_ROOT}/internal/step/certs/kubeadm/backup_certs_before_renew.sh" \
    "certs.renew.etcd.certs:${KUBEXM_ROOT}/internal/step/certs/etcd/renew_etcd_certs.sh"
}

export -f task::renew_kubernetes_ca
export -f task::renew_etcd_ca
export -f task::renew_kubernetes_certs
export -f task::renew_etcd_certs
export -f task::restart_kubernetes_after_cert_renew
export -f task::restart_etcd_after_cert_renew
