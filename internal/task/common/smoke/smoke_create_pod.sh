#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: smoke_create_pod
# 创建测试 Pod (nginx)
# ==============================================================================


step::cluster.smoke.create.pod() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=cluster.smoke.create.pod] Creating test nginx pod..."

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"

  # 检查是否已存在测试 Pod
  if kubectl --kubeconfig="${kubeconfig}" get pod nginx-smoke-test -n default &>/dev/null; then
    logger::info "[host=${host} step=cluster.smoke.create.pod] Pod already exists, skipping..."
    return 0
  fi

  # 创建测试 Pod
  cat << 'EOF' | kubectl --kubeconfig="${kubeconfig}" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-smoke-test
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF

  logger::info "[host=${host} step=cluster.smoke.create.pod] Test pod created"
  return 0
}

step::cluster.smoke.create.pod::run() {
  step::cluster.smoke.create.pod "$@"
}

# 钩子函数
step::cluster.smoke.create.pod::check() {
  return 1  # 总是执行
}

step::cluster.smoke.create.pod::rollback() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"

  kubectl --kubeconfig="${kubeconfig}" delete pod nginx-smoke-test -n default --ignore-not-found &>/dev/null || true
}

step::cluster.smoke.create.pod::targets() {
  # kubectl 操作仅需在本地执行（使用 kubeconfig），不针对特定主机
  return 0
}
