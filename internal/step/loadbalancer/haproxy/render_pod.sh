#!/usr/bin/env bash
set -euo pipefail

step::lb.internal.haproxy.static.render.pod::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_internal_haproxy_static_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/haproxy-pod.yaml" ]]; then
    return 0
  fi
  return 1
}

step::lb.internal.haproxy.static.render.pod::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir
  lb_dir="$(context::get "lb_internal_haproxy_static_dir" || true)"

  cat > "${lb_dir}/haproxy-pod.yaml" <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: haproxy-lb
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: haproxy
    image: haproxy:2.6-alpine
    command: ["/usr/local/sbin/haproxy","-f","/usr/local/etc/haproxy/haproxy.cfg","-db"]
    volumeMounts:
    - name: haproxy-conf
      mountPath: /usr/local/etc/haproxy/haproxy.cfg
      subPath: haproxy.cfg
  volumes:
  - name: haproxy-conf
    hostPath:
      path: /etc/kubernetes/manifests/haproxy.cfg
      type: FileOrCreate
EOF
}

step::lb.internal.haproxy.static.render.pod::rollback() { return 0; }

step::lb.internal.haproxy.static.render.pod::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
