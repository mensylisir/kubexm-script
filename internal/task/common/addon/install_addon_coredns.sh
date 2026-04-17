#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.addon.coredns::check() {
  if kubectl get namespace kube-system &>/dev/null; then
    if kubectl get deployment -n kube-system coredns &>/dev/null; then
      return 0
    fi
  fi
  return 1
}

step::cluster.install.addon.coredns::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local mode first_master k8s_version kubeconfig
  mode=$(config::get_mode)
  first_master=$(config::get_role_members 'control-plane' | head -n1 | awk '{print $1}')
  k8s_version=$(config::get_kubernetes_version)
  kubeconfig="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

  log::info "Installing CoreDNS..."

  if [[ "${mode}" == "offline" && -n "${cluster_name}" ]]; then
    local manifest="${KUBEXM_ROOT}/packages/${cluster_name}/${first_master}/coredns/coredns.yaml"
    if [[ -f "${manifest}" ]]; then
      if ! kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest}"; then
        log::error "Failed to apply CoreDNS manifest: ${manifest}"
        return 1
      fi
    else
      log::error "CoreDNS manifest not found: ${manifest}"
      log::error "Please run 'kubexm download --cluster=${cluster_name}' first"
      return 1
    fi
  else
    # Online mode - use standard CoreDNS deployment
    kubectl --kubeconfig="${kubeconfig}" apply -f - << 'COREDNS_MANIFEST'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:coredns
rules:
  - apiGroups:
    - ""
    resources:
    - endpoints
    - services
    - pods
    - namespaces
    verbs:
    - list
    - watch
  - apiGroups:
    - discovery.k8s.io
    resources:
    - endpointslices
    verbs:
    - list
    - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:coredns
roleRef:
  name: system:coredns
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: coredns
    namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
      log
      errors
      health {
        lameduck 5s
      }
      ready
      kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
      }
      forward . /etc/resolv.conf
      cache 30
      loop
      reload
      loadbalance
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: CoreDNS
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      serviceAccountName: coredns
      priorityClassName: system-cluster-critical
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      nodeSelector:
        kubernetes.io/os: linux
      containers:
        - name: coredns
          image: registry.k8s.io/coredns/coredns:v1.11.1
          imagePullPolicy: IfNotPresent
          args:
            - -conf
            - /etc/coredns/Corefile
          volumeMounts:
            - name: config-volume
              mountPath: /etc/coredns
              readOnly: true
          ports:
            - containerPort: 53
              name: dns
              protocol: UDP
            - containerPort: 53
              name: dns-tcp
              protocol: TCP
            - containerPort: 9153
              name: metrics
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 60
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 5
          readinessProbe:
            httpGet:
              path: /ready
              port: 8181
            initialDelaySeconds: 10
            timeoutSeconds: 5
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 128Mi
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
              - key: Corefile
                path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "kube-dns"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.96.0.10
  ports:
    - name: dns
      port: 53
      protocol: UDP
    - name: dns-tcp
      port: 53
      protocol: TCP
    - name: metrics
      port: 9153
      protocol: TCP
COREDNS_MANIFEST
  fi
}

step::cluster.install.addon.coredns::rollback() { return 0; }

step::cluster.install.addon.coredns::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}