#!/usr/bin/env bash
set -euo pipefail

offline::packages::require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -s "${path}" ]]; then
    echo "missing offline artifact: ${label} (${path})" >&2
    return 1
  fi
}

offline::packages::require_dir() {
  local path="$1"
  local label="$2"
  if [[ ! -d "${path}" ]]; then
    echo "missing offline artifact dir: ${label} (${path})" >&2
    return 1
  fi
}

offline::packages::verify_kubernetes_binaries() {
  local root="$1"
  local k8s_version="$2"
  local arch="$3"
  local k8s_type="$4"

  local base="${root}/kubernetes/${k8s_version}/${arch}"
  offline::packages::require_dir "${base}" "kubernetes/${k8s_version}/${arch}" || return 1

  local binaries=()
  if [[ "${k8s_type}" == "kubeadm" ]]; then
    binaries=("kubeadm" "kubelet" "kubectl")
  else
    binaries=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet" "kubectl" "kube-proxy")
  fi

  local bin
  for bin in "${binaries[@]}"; do
    offline::packages::require_file "${base}/${bin}" "kubernetes/${k8s_version}/${arch}/${bin}" || return 1
  done
}

offline::packages::verify_etcd_binaries() {
  local root="$1"
  local etcd_version="$2"
  local arch="$3"

  local base="${root}/etcd/${etcd_version}/${arch}"
  offline::packages::require_dir "${base}" "etcd/${etcd_version}/${arch}" || return 1
  offline::packages::require_file "${base}/etcd" "etcd/${etcd_version}/${arch}/etcd" || return 1
  offline::packages::require_file "${base}/etcdctl" "etcd/${etcd_version}/${arch}/etcdctl" || return 1
  offline::packages::require_file "${base}/etcdutl" "etcd/${etcd_version}/${arch}/etcdutl" || return 1
}

offline::packages::verify_runtime_binaries() {
  local root="$1"
  local k8s_version="$2"
  local arch="$3"
  local runtime_type="$4"

  local containerd_version
  containerd_version=$(versions::get "containerd" "${k8s_version}")
  local runc_version
  runc_version=$(versions::get "runc" "${k8s_version}")
  local crictl_version
  crictl_version=$(versions::get "crictl" "${k8s_version}")

  case "${runtime_type}" in
    containerd|docker|crio)
      offline::packages::require_file "${root}/containerd/${containerd_version}/${arch}/containerd" "containerd/${containerd_version}/${arch}/containerd" || return 1
      offline::packages::require_file "${root}/runc/${runc_version}/${arch}/runc" "runc/${runc_version}/${arch}/runc" || return 1
      offline::packages::require_file "${root}/crictl/${crictl_version}/${arch}/crictl" "crictl/${crictl_version}/${arch}/crictl" || return 1
      ;;
    *)
      ;;
  esac
}

offline::packages::verify_cni_binaries() {
  local root="$1"
  local k8s_version="$2"
  local arch="$3"

  local cni_version
  cni_version=$(versions::get "cni" "${k8s_version}")
  offline::packages::require_dir "${root}/cni-plugins/${cni_version}/${arch}" "cni-plugins/${cni_version}/${arch}" || return 1
}

offline::packages::verify_common_tools() {
  local root="$1"
  local arch="$2"

  local base="${root}/tools/common/${arch}"
  offline::packages::require_dir "${base}" "tools/common/${arch}" || return 1
  offline::packages::require_file "${base}/yq" "tools/common/${arch}/yq" || return 1
  if [[ "${arch}" == "amd64" ]]; then
    offline::packages::require_file "${base}/jq" "tools/common/${arch}/jq" || return 1
  fi
  offline::packages::require_file "${base}/skopeo" "tools/common/${arch}/skopeo" || return 1
  offline::packages::require_file "${base}/etcdctl" "tools/common/${arch}/etcdctl" || return 1
}

offline::packages::verify_calicoctl() {
  local root="$1"
  local k8s_version="$2"
  local arch="$3"

  local calico_version
  calico_version=$(versions::get "calico" "${k8s_version}")
  offline::packages::require_file "${root}/calicoctl/${calico_version}/${arch}/calicoctl" "calicoctl/${calico_version}/${arch}/calicoctl" || return 1
}

offline::packages::verify_registry_binary() {
  local root="$1"
  local registry_version="$2"
  local arch="$3"

  offline::packages::require_file "${root}/registry/${registry_version}/${arch}/registry" "registry/${registry_version}/${arch}/registry" || return 1
}

offline::packages::verify_helm_binary() {
  local root="$1"
  local k8s_version="$2"
  local arch="$3"

  local helm_version
  helm_version=$(versions::get "helm" "${k8s_version}")
  offline::packages::require_file "${root}/helm/${helm_version}/${arch}/helm" "helm/${helm_version}/${arch}/helm" || return 1
}

offline::packages::verify_images() {
  local root="$1"
  local image_list=()
  local image
  while IFS= read -r image; do
    [[ -z "${image}" ]] && continue
    [[ "${image}" =~ ^# ]] && continue
    image_list+=("${image}")
  done

  if [[ ${#image_list[@]} -eq 0 ]]; then
    return 0
  fi

  local image_name
  local image_dir
  for image in "${image_list[@]}"; do
    image_name=$(echo "${image}" | tr '/' '_' | tr ':' '_')
    image_dir="${root}/images/${image_name}"
    if [[ -f "${image_dir}/manifest.json" ]]; then
      continue
    fi
    if [[ -f "${image_dir}/oci-layout" ]]; then
      continue
    fi
    offline::packages::require_file "${image_dir}/manifest.json" "images/${image_name}/manifest.json" || return 1
  done
}

offline::packages::verify_images_from_list() {
  local root="$1"
  local list_file="${root}/images/images.list"
  if [[ ! -f "${list_file}" && -f "${root}/images.list" ]]; then
    list_file="${root}/images.list"
  fi

  if [[ ! -f "${list_file}" ]]; then
    return 1
  fi

  local count
  count=$(grep -v '^#' "${list_file}" | grep -v '^$' | wc -l)
  if [[ "${count}" -eq 0 ]]; then
    return 1
  fi

  offline::packages::verify_images "${root}" < "${list_file}"
}

offline::packages::verify_helm_charts() {
  local root="$1"
  local enabled_addons

  enabled_addons=$(image_manager::get_enabled_addons || true)
  if [[ -z "${enabled_addons}" ]]; then
    return 0
  fi

  local item name conf release relpath
  while IFS= read -r item; do
    [[ -z "${item}" ]] && continue
    IFS=':' read -r name conf release relpath <<< "${item}"
    offline::packages::require_dir "${root}/${relpath}" "${relpath}" || return 1
  done <<< "${enabled_addons}"
}

offline::packages::verify() {
  local root="$1"
  local k8s_version="$2"
  local k8s_type="$3"
  local etcd_type="$4"
  local runtime_type="$5"
  local network_plugin="$6"
  local lb_enabled="$7"
  local lb_mode="$8"
  local lb_type="$9"
  local arch_list="${10}"

  local arch
  for arch in ${arch_list}; do
    offline::packages::verify_kubernetes_binaries "${root}" "${k8s_version}" "${arch}" "${k8s_type}" || return 1
    offline::packages::verify_runtime_binaries "${root}" "${k8s_version}" "${arch}" "${runtime_type}" || return 1
    offline::packages::verify_common_tools "${root}" "${arch}" || return 1
    offline::packages::verify_helm_binary "${root}" "${k8s_version}" "${arch}" || return 1
    offline::packages::verify_cni_binaries "${root}" "${k8s_version}" "${arch}" || return 1
    if [[ "${network_plugin}" == "calico" ]]; then
      offline::packages::verify_calicoctl "${root}" "${k8s_version}" "${arch}" || return 1
    fi
    if [[ "${etcd_type}" == "kubexm" ]]; then
      local etcd_version
      etcd_version=$(versions::get "etcd" "${k8s_version}")
      offline::packages::verify_etcd_binaries "${root}" "${etcd_version}" "${arch}" || return 1
    fi
    if [[ "${lb_enabled}" == "true" && "${lb_mode}" == "external" ]]; then
      if [[ "${lb_type}" == "kubexm-kh" || "${lb_type}" == "kubexm-kn" ]]; then
        local registry_version
        registry_version=$(defaults::get_registry_version)
        offline::packages::verify_registry_binary "${root}" "${registry_version}" "${arch}" || return 1
      fi
    fi
  done

  if ! offline::packages::verify_images_from_list "${root}"; then
    local images
    images=$(generate_core_images "${k8s_version}" "" "${k8s_type}" "${etcd_type}" "${network_plugin}" "${lb_enabled}" "${lb_mode}" "${lb_type}")
    if [[ "${lb_mode}" == "kube-vip" ]]; then
      images+=$'\n'"ghcr.io/kube-vip/kube-vip:$(defaults::get_kubevip_version)"
    fi
    offline::packages::verify_images "${root}" <<< "${images}" || return 1
  fi

  offline::packages::verify_helm_charts "${root}" || return 1
}
