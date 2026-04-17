#!/usr/bin/env bash
set -euo pipefail

step::cluster.etcd.auto.backup.collect::check() { return 1; }

step::cluster.etcd.auto.backup.collect::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"
  source "${KUBEXM_ROOT}/internal/utils/template.sh"

  local auto_backup
  auto_backup=$(config::get "spec.etcd.autoBackupEtcd" "false" 2>/dev/null || echo "false")
  if [[ "${auto_backup}" != "true" ]]; then
    log::info "Auto backup is disabled (spec.etcd.autoBackupEtcd=false)"
    context::set "etcd_backup_enabled" "false"
    return 0
  fi

  local backup_dir retention_days backup_schedule
  backup_dir=$(config::get "spec.backup.etcd.backup_dir" "/var/backups/etcd" 2>/dev/null || echo "/var/backups/etcd")
  retention_days=$(config::get "spec.backup.etcd.retention_days" "7" 2>/dev/null || echo "7")
  backup_schedule=$(config::get "spec.backup.etcd.schedule" "*-*-* 02:00:00" 2>/dev/null || echo "*-*-* 02:00:00")

  local etcd_type
  etcd_type=$(config::get_etcd_type)
  local etcd_cert_dir="/etc/kubernetes/pki/etcd"
  if [[ "${etcd_type}" == "kubexm" || "${etcd_type}" == "exists" ]]; then
    etcd_cert_dir="/etc/etcd/ssl"
  fi

  local node_name
  node_name=$(identity::resolve_node_name)
  local node_ip="${KUBEXM_HOST}"

  local base_dir
  base_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/etcd-backup"
  mkdir -p "${base_dir}"

  local script_file service_file timer_file
  script_file="${base_dir}/etcd-backup.sh"
  service_file="${base_dir}/etcd-backup.service"
  timer_file="${base_dir}/etcd-backup.timer"

  cat > "${script_file}" <<EOF_SCRIPT
#!/bin/bash
set -e

BACKUP_DIR="\${ETCD_BACKUP_DIR:-${backup_dir}}"
RETENTION_DAYS=\${ETCD_BACKUP_KEEP:-${retention_days}}
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/etcd-snapshot-\${TIMESTAMP}.db"
CERT_DIR="\${ETCD_CERT_DIR:-${etcd_cert_dir}}"
ENDPOINTS="\${ETCD_ENDPOINTS:-https://127.0.0.1:2379}"

mkdir -p \${BACKUP_DIR}

echo "\$(date): Starting etcd backup..."

ETCDCTL_API=3 etcdctl snapshot save \${BACKUP_FILE} \
  --endpoints=\${ENDPOINTS} \
  --cacert=\${CERT_DIR}/ca.crt \
  --cert=\${CERT_DIR}/server.crt \
  --key=\${CERT_DIR}/server.key

if [ \$? -eq 0 ]; then
  echo "\$(date): Backup successful: \${BACKUP_FILE}"
  BACKUP_SIZE=\$(du -sh \${BACKUP_FILE} | cut -f1)
  echo "\$(date): Backup size: \${BACKUP_SIZE}"

  OLD_COUNT=\$(find \${BACKUP_DIR} -name 'etcd-snapshot-*.db' -mtime +\${RETENTION_DAYS} | wc -l)
  find \${BACKUP_DIR} -name 'etcd-snapshot-*.db' -mtime +\${RETENTION_DAYS} -delete
  echo "\$(date): Cleaned up \${OLD_COUNT} old backup(s)"
else
  echo "\$(date): Backup failed" >&2
  exit 1
fi
EOF_SCRIPT

  chmod +x "${script_file}"

  local service_template
  if [[ "${etcd_type}" == "kubeadm" ]]; then
    service_template="${KUBEXM_ROOT}/templates/systemd/etcd-backup-kubeadm.service.tmpl"
  else
    service_template="${KUBEXM_ROOT}/templates/systemd/etcd-backup-kubexm.service.tmpl"
  fi

  if [[ -f "${service_template}" ]]; then
    template::render_with_vars "${service_template}" "${service_file}" \
      "ETCD_BACKUP_DIR=${backup_dir}" \
      "ETCD_BACKUP_KEEP=${retention_days}" \
      "ETCD_CERT_DIR=${etcd_cert_dir}" \
      "ETCD_ENDPOINTS=https://${node_ip}:2379"
  else
    local fallback_template="${KUBEXM_ROOT}/templates/systemd/etcd-backup.service.tmpl"
    if [[ -f "${fallback_template}" ]]; then
      template::render_with_vars "${fallback_template}" "${service_file}" \
        "ETCD_BACKUP_DIR=${backup_dir}" \
        "ETCD_BACKUP_KEEP=${retention_days}" \
        "ETCD_CERT_DIR=${etcd_cert_dir}" \
        "ETCD_ENDPOINTS=https://${node_ip}:2379"
    else
      cat > "${service_file}" <<EOF_SERVICE
[Unit]
Description=Etcd Automatic Backup
After=etcd.service

[Service]
Type=oneshot
Environment=ETCD_ENDPOINTS=https://${node_ip}:2379
Environment=ETCD_CERT_DIR=${etcd_cert_dir}
Environment=ETCD_BACKUP_DIR=${backup_dir}
Environment=ETCD_BACKUP_KEEP=${retention_days}
ExecStart=/usr/local/bin/etcd-backup.sh
StandardOutput=journal
StandardError=journal
EOF_SERVICE
    fi
  fi

  local timer_template
  timer_template="${KUBEXM_ROOT}/templates/systemd/etcd-backup.timer.tmpl"
  if [[ -f "${timer_template}" ]]; then
    template::render_with_vars "${timer_template}" "${timer_file}" \
      "ETCD_BACKUP_SCHEDULE=${backup_schedule}"
  else
    cat > "${timer_file}" <<EOF_TIMER
[Unit]
Description=Etcd Backup Timer
Requires=etcd-backup.service

[Timer]
OnCalendar=${backup_schedule}
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF_TIMER
  fi

  context::set "etcd_backup_enabled" "true"
  context::set "etcd_backup_script" "${script_file}"
  context::set "etcd_backup_service" "${service_file}"
  context::set "etcd_backup_timer" "${timer_file}"
}

step::cluster.etcd.auto.backup.collect::rollback() { return 0; }

step::cluster.etcd.auto.backup.collect::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
