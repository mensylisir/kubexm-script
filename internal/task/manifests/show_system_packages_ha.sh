#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.system.packages.ha::check() { return 1; }

step::manifests.show.system.packages.ha::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local lb_type lb_mode k8s_type has_ha
  lb_type="$(context::get "manifests_system_packages_lb_type" || true)"
  lb_mode="$(context::get "manifests_system_packages_lb_mode" || true)"
  k8s_type="$(context::get "manifests_system_packages_k8s_type" || true)"
  has_ha="$(context::get "manifests_system_packages_has_ha" || true)"

  if [[ "${has_ha}" != "true" ]]; then
    return 0
  fi

  echo "  高可用负载均衡器包（已启用高可用时安装）:"
  case "$lb_type" in
    kubexm-kh)
      echo "    - $(defaults::get_rpm_package_name "keepalived") (负载均衡器节点)"
      echo "    - $(defaults::get_rpm_package_name "haproxy") (负载均衡器节点)"
      ;;
    kubexm-kn)
      echo "    - $(defaults::get_rpm_package_name "keepalived") (负载均衡器节点)"
      echo "    - $(defaults::get_rpm_package_name "nginx") (负载均衡器节点)"
      ;;
    haproxy)
      if [[ "$lb_mode" == "internal" ]]; then
        if [[ "$k8s_type" == "kubexm" ]]; then
          echo "    - $(defaults::get_rpm_package_name "haproxy") (负载均衡器节点)"
        elif [[ "$k8s_type" == "kubeadm" ]]; then
          echo "    使用静态pod部署，无需系统包"
        fi
      elif [[ "$lb_mode" == "exists" ]]; then
        echo "    用户已准备好负载均衡，程序无需部署"
      fi
      ;;
    nginx)
      if [[ "$lb_mode" == "internal" ]]; then
        if [[ "$k8s_type" == "kubexm" ]]; then
          echo "    - $(defaults::get_rpm_package_name "nginx") (负载均衡器节点)"
        elif [[ "$k8s_type" == "kubeadm" ]]; then
          echo "    使用静态pod部署，无需系统包"
        fi
      elif [[ "$lb_mode" == "exists" ]]; then
        echo "    用户已准备好负载均衡，程序无需部署"
      fi
      ;;
    kube-vip)
      echo "    使用静态pod部署，无需系统包"
      ;;
  esac
  echo
}

step::manifests.show.system.packages.ha::rollback() { return 0; }

step::manifests.show.system.packages.ha::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
