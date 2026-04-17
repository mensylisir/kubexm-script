#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.binaries::check() { return 1; }

step::manifests.show.binaries::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"

  local k8s_version k8s_type etcd_type arch cni
  k8s_version="$(context::get "manifests_k8s_version" || true)"
  k8s_type="$(context::get "manifests_k8s_type" || true)"
  etcd_type="$(context::get "manifests_etcd_type" || true)"
  arch="$(context::get "manifests_arch" || true)"
  cni="$(context::get "manifests_cni" || true)"

  local cni_version
  cni_version=$(versions::get "cni" "$k8s_version") || cni_version=$(defaults::get_cni_version)

  echo "=== Kubernetes二进制文件 ==="
  IFS=',' read -r -a arch_array <<< "${arch}"
  for a in "${arch_array[@]}"; do
    a=$(echo "$a" | xargs)
    if [[ -z "$a" ]]; then continue; fi

    echo "  [${a}]"
    if [[ "$k8s_type" == "kubeadm" ]]; then
      echo "    kubeadm: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kubeadm")"
      echo "    kubelet: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kubelet")"
      echo "    kubectl: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kubectl")"
      echo "    (注: kube-proxy通过DaemonSet部署，不下载二进制)"
    else
      echo "    kube-apiserver: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kube-apiserver")"
      echo "    kube-controller-manager: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kube-controller-manager")"
      echo "    kube-scheduler: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kube-scheduler")"
      echo "    kubelet: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kubelet")"
      echo "    kubectl: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kubectl")"
      echo "    kube-proxy: $(versions::get_k8s_binary_url "${a}" "${k8s_version}" "kube-proxy")"
    fi
  done

  for a in "${arch_array[@]}"; do
    a=$(echo "$a" | xargs)
    if [[ -z "$a" ]]; then continue; fi
    echo "  CNI Plugins [${a}]: $(versions::get_cni_download_url "${a}" "${cni_version}")"
  done

  if [[ "$etcd_type" == "kubexm" ]]; then
    local etcd_version
    etcd_version=$(versions::get "etcd" "$k8s_version") || etcd_version=$(defaults::get_etcd_version)
    for a in "${arch_array[@]}"; do
       a=$(echo "$a" | xargs)
       if [[ -z "$a" ]]; then continue; fi
       local etcd_url
       etcd_url=$(versions::get_etcd_url "${a}" "${etcd_version}")
       echo "  etcd [${a}]: ${etcd_url}"
    done
  elif [[ "$etcd_type" == "kubeadm" ]]; then
    echo "  kubeadm形式部署etcd,无需下载etcd二进制"
  elif [[ "$etcd_type" == "exists" ]]; then
    echo "  用户已有etcd,无需本程序部署"
  fi
  echo
}

step::manifests.show.binaries::rollback() { return 0; }

step::manifests.show.binaries::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
