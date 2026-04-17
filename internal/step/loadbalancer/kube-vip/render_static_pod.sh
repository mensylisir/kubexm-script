#!/usr/bin/env bash
set -euo pipefail

step::lb.kube.vip.render.static.pod::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local first_master out_file
  first_master="$(context::get "lb_kube_vip_first_master" || true)"
  if [[ -z "${first_master}" ]]; then
    return 1
  fi
  out_file="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/${first_master}/loadbalancer/kube-vip/kube-vip-static.yaml"
  if [[ -f "${out_file}" ]]; then
    return 0
  fi
  return 1
}

step::lb.kube.vip.render.static.pod::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local deploy_mode
  deploy_mode="$(context::get "lb_kube_vip_deploy_mode" || true)"
  if [[ "${deploy_mode}" != "static-pod" ]]; then
    return 0
  fi

  local vip_address interface first_master
  vip_address="$(context::get "lb_kube_vip_vip" || true)"
  interface="$(context::get "lb_kube_vip_interface" || true)"
  first_master="$(context::get "lb_kube_vip_first_master" || true)"
  if [[ -z "${first_master}" ]]; then
    return 1
  fi

  # NOTE: 使用 <<"EOF" 防止 heredoc 内容被双展开，允许 ${vip_address}/${interface} 正常展开，
  # 但阻止 $(cmd)/`cmd` 等命令替换被意外执行
  local kube_vip_pod
  kube_vip_pod=$(
    cat << "EOF"
apiVersion: v1
kind: Pod
metadata:
  name: kube-vip
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-vip
    image: ghcr.io/kube-vip/kube-vip:v0.8.0
    imagePullPolicy: IfNotPresent
    args:
    - manager
    env:
    - name: vip_address
      value: "${vip_address}"
    - name: vip_interface
      value: "${interface}"
    securityContext:
      capabilities:
        add: ["NET_ADMIN","NET_RAW"]
EOF
  )

  local out_dir out_file
  out_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}/${first_master}/loadbalancer/kube-vip"
  out_file="${out_dir}/kube-vip-static.yaml"
  mkdir -p "${out_dir}"
  printf '%s\n' "${kube_vip_pod}" > "${out_file}"
  context::set "lb_kube_vip_static_pod_file" "${out_file}"
}

step::lb.kube.vip.render.static.pod::rollback() { return 0; }

step::lb.kube.vip.render.static.pod::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}