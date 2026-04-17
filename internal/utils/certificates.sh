#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certificate Utilities
# ==============================================================================
# Provides certificate management utilities:
# - Expiry checking
# - Emergency renewal for expired certs
# - Ordered service restart
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"

#######################################
# Check certificate expiry date
# Arguments:
#   $1 - Path to certificate file
# Returns:
#   0 - Certificate valid
#   1 - Certificate expiring soon (<30 days)
#   2 - Certificate EXPIRED
# Outputs:
#   Writes expiry info to stdout
#######################################
cert::check_expiry() {
  local cert_file="$1"

  if [[ ! -f "${cert_file}" ]]; then
    log::error "Certificate file not found: ${cert_file}"
    return 1
  fi

  local expiry_date
  expiry_date=$(openssl x509 -enddate -noout -in "${cert_file}" 2>/dev/null | cut -d= -f2) || {
    log::error "Failed to read certificate: ${cert_file}"
    return 1
  }

  local expiry_epoch
  expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null) || {
    # Try alternative date format
    expiry_epoch=$(date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null) || {
      log::error "Failed to parse certificate expiry date: ${expiry_date}"
      return 1
    }
  }

  local now_epoch
  now_epoch=$(date +%s)
  local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

  if [[ ${days_remaining} -lt 0 ]]; then
    log::error "❌ CERTIFICATE EXPIRED ${days_remaining} days ago: ${cert_file}"
    log::error "   Expiry date: ${expiry_date}"
    return 2
  elif [[ ${days_remaining} -lt 30 ]]; then
    log::warn "⚠️  Certificate expires in ${days_remaining} days: ${cert_file}"
    log::warn "   Expiry date: ${expiry_date}"
    return 1
  else
    log::info "✓ Certificate valid for ${days_remaining} days: ${cert_file}"
    return 0
  fi
}

#######################################
# Check all certificates in a directory
# Arguments:
#   $1 - Directory containing certificates
# Returns:
#   0 - All certificates valid
#   1 - Some certificates expiring soon
#   2 - Some certificates EXPIRED (critical)
#######################################
cert::check_directory() {
  local cert_dir="$1"
  local has_expired=0
  local has_expiring_soon=0

  if [[ ! -d "${cert_dir}" ]]; then
    log::error "Certificate directory not found: ${cert_dir}"
    return 1
  fi

  log::info "Checking certificates in: ${cert_dir}"

  while IFS= read -r -d '' cert_file; do
    local result=0
    cert::check_expiry "${cert_file}" || result=$?

    case ${result} in
      2) has_expired=1 ;;
      1) has_expiring_soon=1 ;;
    esac
  done < <(find "${cert_dir}" -name "*.crt" -o -name "*.pem" | tr '\n' '\0')

  if [[ ${has_expired} -eq 1 ]]; then
    log::error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::error "CRITICAL: One or more certificates have EXPIRED!"
    log::error "Action required: Run emergency certificate renewal"
    log::error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 2
  elif [[ ${has_expiring_soon} -eq 1 ]]; then
    log::warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log::warn "WARNING: Some certificates expiring within 30 days"
    log::warn "Recommended: Schedule certificate renewal soon"
    log::warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 1
  else
    log::info "All certificates are valid"
    return 0
  fi
}

#######################################
# Emergency certificate renewal procedure
# For use when certificates have already expired
# Arguments:
#   $1 - Cluster context
#   $@ - Additional arguments
# Returns:
#   0 - Success
#   1 - Failure
#######################################
cert::emergency_renewal() {
  local ctx="$1"
  shift

  log::warn "═══════════════════════════════════════════════════════"
  log::warn "EMERGENCY CERTIFICATE RENEWAL PROCEDURE"
  log::warn "This will stop all services and regenerate certificates"
  log::warn "═══════════════════════════════════════════════════════"

  local k8s_type
  k8s_type=$(config::get_kubernetes_type 2>/dev/null || echo "kubeadm")
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo "kubeadm")

  # Step 1: Stop all Kubernetes services
  log::info "[Emergency Renewal] Step 1/6: Stopping Kubernetes services..."
  _cert_stop_kubernetes_services || {
    log::error "Failed to stop Kubernetes services"
    return 1
  }

  # Step 2: Stop etcd if standalone
  if [[ "${etcd_type}" == "kubexm" ]]; then
    log::info "[Emergency Renewal] Step 2/6: Stopping etcd..."
    _cert_stop_etcd_service || {
      log::error "Failed to stop etcd"
      return 1
    }
  fi

  # Step 3: Backup old certificates
  log::info "[Emergency Renewal] Step 3/6: Backing up old certificates..."
  _cert_backup_old_certs || {
    log::error "Failed to backup old certificates"
    return 1
  }

  # Step 4: Generate new certificates
  log::info "[Emergency Renewal] Step 4/6: Generating new certificates..."
  if [[ "${k8s_type}" == "kubeadm" ]]; then
    _cert_renew_kubeadm_certs || {
      log::error "Failed to renew kubeadm certificates"
      _cert_restore_old_certs || log::warn "Failed to restore old certs"
      return 1
    }
  else
    _cert_renew_kubexm_certs "${ctx}" "$@" || {
      log::error "Failed to renew kubexm certificates"
      _cert_restore_old_certs || log::warn "Failed to restore old certs"
      return 1
    }
  fi

  # Step 5: Start etcd if standalone
  if [[ "${etcd_type}" == "kubexm" ]]; then
    log::info "[Emergency Renewal] Step 5/6: Starting etcd..."
    _cert_start_etcd_service || {
      log::error "Failed to start etcd"
      _cert_restore_old_certs || log::warn "Failed to restore old certs"
      return 1
    }
  fi

  # Step 6: Start Kubernetes services in order
  log::info "[Emergency Renewal] Step 6/6: Starting Kubernetes services..."
  _cert_start_kubernetes_services_ordered || {
    log::error "Failed to start Kubernetes services"
    _cert_restore_old_certs || log::warn "Failed to restore old certs"
    return 1
  }

  log::info "═══════════════════════════════════════════════════════"
  log::info "Emergency certificate renewal completed successfully!"
  log::info "Please verify cluster health: kubectl get nodes"
  log::info "═══════════════════════════════════════════════════════"
  return 0
}

#######################################
# Restart Kubernetes services in correct order
# Arguments:
#   None
# Returns:
#   0 - Success
#   1 - Failure
#######################################
cert::restart_kubernetes_ordered() {
  log::info "Restarting Kubernetes services in ordered sequence..."

  local services=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet")

  for service in "${services[@]}"; do
    log::info "  Restarting ${service}..."
    if ! systemctl restart "${service}" 2>/dev/null; then
      log::error "Failed to restart ${service}"
      return 1
    fi

    # Wait for service to be healthy
    if ! _cert_wait_for_service_healthy "${service}" 30; then
      log::error "${service} failed to become healthy within 30 seconds"
      return 1
    fi

    log::info "  ✓ ${service} is healthy"
  done

  log::info "All Kubernetes services restarted successfully"
  return 0
}

#######################################
# Restart etcd service
# Arguments:
#   None
# Returns:
#   0 - Success
#   1 - Failure
#######################################
cert::restart_etcd() {
  log::info "Restarting etcd service..."

  if ! systemctl restart etcd 2>/dev/null; then
    log::error "Failed to restart etcd"
    return 1
  fi

  if ! _cert_wait_for_service_healthy "etcd" 30; then
    log::error "etcd failed to become healthy within 30 seconds"
    return 1
  fi

  log::info "✓ etcd is healthy"
  return 0
}

# ==============================================================================
# Internal helper functions
# ==============================================================================

_cert_stop_kubernetes_services() {
  local services=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet")
  for service in "${services[@]}"; do
    log::info "  Stopping ${service}..."
    systemctl stop "${service}" 2>/dev/null || true
  done
  sleep 2
}

_cert_stop_etcd_service() {
  log::info "  Stopping etcd..."
  systemctl stop etcd 2>/dev/null || true
  sleep 2
}

_cert_backup_old_certs() {
  local pki_dir="/etc/kubernetes/pki"
  local backup_dir="${pki_dir}.backup.$(date +%Y%m%d%H%M%S)"

  if [[ -d "${pki_dir}" ]]; then
    cp -a "${pki_dir}" "${backup_dir}" || return 1
    log::info "  Old certificates backed up to: ${backup_dir}"
  fi
}

_cert_restore_old_certs() {
  local pki_dir="/etc/kubernetes/pki"
  local backup_dir
  backup_dir=$(ls -td ${pki_dir}.backup.* 2>/dev/null | head -1)

  if [[ -n "${backup_dir}" && -d "${backup_dir}" ]]; then
    log::warn "Restoring old certificates from: ${backup_dir}"
    rm -rf "${pki_dir}"
    cp -a "${backup_dir}" "${pki_dir}" || return 1
  fi
}

_cert_renew_kubeadm_certs() {
  log::info "  Renewing kubeadm certificates..."
  if ! kubeadm certs renew all 2>/dev/null; then
    log::error "kubeadm certs renew failed"
    return 1
  fi
}

_cert_renew_kubexm_certs() {
  local ctx="$1"
  shift
  # Call the existing kubexm cert renewal task
  source "${KUBEXM_ROOT}/internal/task/certs/renew.sh"
  task::renew_kubernetes_certs "${ctx}" "$@" || return $?
}

_cert_start_etcd_service() {
  log::info "  Starting etcd..."
  systemctl start etcd 2>/dev/null || return 1
  sleep 3
}

_cert_start_kubernetes_services_ordered() {
  log::info "  Starting services in order: etcd → apiserver → controller-manager → scheduler → kubelet"

  # Start etcd first if standalone
  local etcd_type
  etcd_type=$(config::get_etcd_type 2>/dev/null || echo "kubeadm")
  if [[ "${etcd_type}" == "kubexm" ]]; then
    systemctl start etcd 2>/dev/null || return 1
    sleep 3
  fi

  # Start Kubernetes components in order
  systemctl start kube-apiserver 2>/dev/null || return 1
  sleep 3
  systemctl start kube-controller-manager 2>/dev/null || return 1
  sleep 2
  systemctl start kube-scheduler 2>/dev/null || return 1
  sleep 2
  systemctl start kubelet 2>/dev/null || return 1

  log::info "  All services started"
}

_cert_wait_for_service_healthy() {
  local service_name="$1"
  local timeout="$2"
  local elapsed=0

  while [[ ${elapsed} -lt ${timeout} ]]; do
    if systemctl is-active --quiet "${service_name}" 2>/dev/null; then
      return 0
    fi
    sleep 1
    ((elapsed++))
  done

  return 1
}

export -f cert::check_expiry
export -f cert::check_directory
export -f cert::emergency_renewal
export -f cert::restart_kubernetes_ordered
export -f cert::restart_etcd
