#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.nginx.static.render.pod::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_internal_nginx_static_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/nginx-pod.yaml" ]]; then
    return 0
  fi
  return 1
}

step::lb.internal.nginx.static.render.pod::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir
  lb_dir="$(context::get "lb_internal_nginx_static_dir" || true)"

  cat > "${lb_dir}/nginx-pod.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nginx-lb
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: nginx
    image: nginx:1.20-alpine
    volumeMounts:
    - name: nginx-conf
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
  volumes:
  - name: nginx-conf
    hostPath:
      path: /etc/kubernetes/manifests/nginx.conf
      type: FileOrCreate
EOF
}

step::lb.internal.nginx.static.render.pod::rollback() { return 0; }

step::lb.internal.nginx.static.render.pod::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
