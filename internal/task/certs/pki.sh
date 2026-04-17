#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - PKI Certificate Manager
# ==============================================================================
# 管理Kubernetes集群的PKI证书生成和分发
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"

# ==============================================================================
# PKI证书管理
# ==============================================================================

#######################################
# 生成CA证书
# Arguments:
#   $1 - 输出目录
# Returns:
#   0 on success, 1 on failure
#######################################
pki::generate_ca() {
  local output_dir="$1"

  log::info "Generating CA certificate..."

  mkdir -p "${output_dir}"

  # 生成CA私钥
  if ! openssl genrsa -out "${output_dir}/ca-key.pem" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate CA private key"
    return 1
  fi

  # 生成CA证书
  local validity_days="${KUBEXM_CERT_VALIDITY_DAYS:-$(defaults::get_cert_validity_days)}"
  if ! openssl req -x509 -new -nodes -key "${output_dir}/ca-key.pem" \
    -sha256 -days "${validity_days}" -out "${output_dir}/ca.crt" \
    -subj "/CN=kubernetes-ca" >/dev/null 2>&1; then
    log::error "Failed to generate CA certificate"
    return 1
  fi

  # 设置权限
  chmod 600 "${output_dir}/ca-key.pem"
  chmod 644 "${output_dir}/ca.crt"
  # 兼容常用命名
  if [[ ! -f "${output_dir}/ca.key" ]]; then
    cp "${output_dir}/ca-key.pem" "${output_dir}/ca.key"
    chmod 600 "${output_dir}/ca.key"
  fi

  log::success "CA certificate generated successfully"
  return 0
}

#######################################
# 生成API Server证书
# Arguments:
#   $1 - 输出目录
#   $2 - 集群域名
#   $3 - API Server地址列表
# Returns:
#   0 on success, 1 on failure
#######################################
pki::apiserver::generate_all() {
  local output_dir="$1"
  local cluster_domain="$2"
  local api_servers="$3"

  log::info "Generating API Server certificates..."

  mkdir -p "${output_dir}"

  # 生成API Server私钥
  if ! openssl genrsa -out "${output_dir}/apiserver.key" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate API Server private key"
    return 1
  fi
  # 兼容旧命名
  cp "${output_dir}/apiserver.key" "${output_dir}/apiserver-key.pem"

  # 生成证书签名请求
  local csr_file="${output_dir}/apiserver.csr"

  # 构建SAN列表
  local sans="DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.${cluster_domain},DNS:localhost,IP:127.0.0.1"

  # 添加API Server地址
  for server in ${api_servers}; do
    sans+=",IP:${server}"
  done

  # 添加Service Cluster IP (从 service_cidr 计算第一个 IP)
  local service_cidr
  service_cidr=$(config::get "spec.kubernetes.service_cidr" "$(defaults::get_service_cidr)" 2>/dev/null || defaults::get_service_cidr)
  local service_cluster_ip
  service_cluster_ip=$(echo "${service_cidr}" | sed 's|/.*||' | sed 's/\.[0-9]*$/\.1/')
  sans+=",IP:${service_cluster_ip}"

  if ! openssl req -new -key "${output_dir}/apiserver.key" \
    -out "${csr_file}" \
    -subj "/CN=kube-apiserver" \
    -addext "subjectAltName = ${sans}" >/dev/null 2>&1; then
    log::error "Failed to generate API Server CSR"
    return 1
  fi

  # 签署证书
  if ! openssl x509 -req -in "${csr_file}" \
    -CA "${output_dir}/ca.crt" \
    -CAkey "${output_dir}/ca-key.pem" \
    -CAcreateserial \
    -out "${output_dir}/apiserver.crt" \
    -extensions v3_req \
    -extfile <(cat << EOF
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.${cluster_domain}
DNS.5 = localhost
EOF
) -days 3650 >/dev/null 2>&1; then
    log::error "Failed to sign API Server certificate"
    return 1
  fi

  # 清理临时文件
  rm -f "${csr_file}"

  # 设置权限
  chmod 600 "${output_dir}/apiserver.key" "${output_dir}/apiserver-key.pem"
  chmod 644 "${output_dir}/apiserver.crt"

  log::success "API Server certificates generated successfully"
  return 0
}

#######################################
# 生成前端代理证书
# Arguments:
#   $1 - 输出目录
# Returns:
#   0 on success, 1 on failure
#######################################
pki::front_proxy::generate_all() {
  local output_dir="$1"

  log::info "Generating front-proxy certificates..."

  mkdir -p "${output_dir}"

  # 生成front-proxy CA私钥
  if ! openssl genrsa -out "${output_dir}/front-proxy-ca-key.pem" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate front-proxy CA private key"
    return 1
  fi

  # 生成front-proxy CA证书
  if ! openssl req -x509 -new -nodes -key "${output_dir}/front-proxy-ca-key.pem" \
    -sha256 -days 3650 -out "${output_dir}/front-proxy-ca.crt" \
    -subj "/CN=front-proxy-ca" >/dev/null 2>&1; then
    log::error "Failed to generate front-proxy CA certificate"
    return 1
  fi

  # 生成front-proxy客户端私钥
  if ! openssl genrsa -out "${output_dir}/front-proxy-client-key.pem" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate front-proxy client private key"
    return 1
  fi

  # 生成front-proxy客户端证书签名请求
  if ! openssl req -new -key "${output_dir}/front-proxy-client-key.pem" \
    -out "${output_dir}/front-proxy-client.csr" \
    -subj "/CN=front-proxy-client" >/dev/null 2>&1; then
    log::error "Failed to generate front-proxy client CSR"
    return 1
  fi

  # 签署front-proxy客户端证书
  if ! openssl x509 -req -in "${output_dir}/front-proxy-client.csr" \
    -CA "${output_dir}/front-proxy-ca.crt" \
    -CAkey "${output_dir}/front-proxy-ca-key.pem" \
    -CAcreateserial \
    -out "${output_dir}/front-proxy-client.crt" \
    -days 3650 >/dev/null 2>&1; then
    log::error "Failed to sign front-proxy client certificate"
    return 1
  fi

  # 清理临时文件
  rm -f "${output_dir}/front-proxy-client.csr"

  # 设置权限
  chmod 600 "${output_dir}/front-proxy-ca-key.pem"
  chmod 600 "${output_dir}/front-proxy-client-key.pem"
  chmod 644 "${output_dir}/front-proxy-ca.crt"
  chmod 644 "${output_dir}/front-proxy-client.crt"
  # 兼容常用命名
  if [[ ! -f "${output_dir}/front-proxy-ca.key" ]]; then
    cp "${output_dir}/front-proxy-ca-key.pem" "${output_dir}/front-proxy-ca.key"
    chmod 600 "${output_dir}/front-proxy-ca.key"
  fi
  if [[ ! -f "${output_dir}/front-proxy-client.key" ]]; then
    cp "${output_dir}/front-proxy-client-key.pem" "${output_dir}/front-proxy-client.key"
    chmod 600 "${output_dir}/front-proxy-client.key"
  fi

  log::success "Front-proxy certificates generated successfully"
  return 0
}

#######################################
# 生成Service Account密钥对
# Arguments:
#   $1 - 输出目录
# Returns:
#   0 on success, 1 on failure
#######################################
pki::sa::generate_keypair() {
  local output_dir="$1"

  log::info "Generating Service Account keypair..."

  mkdir -p "${output_dir}"

  # 生成私钥
  if ! openssl genrsa -out "${output_dir}/sa.key" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate Service Account private key"
    return 1
  fi

  # 生成公钥
  if ! openssl rsa -in "${output_dir}/sa.key" -pubout -out "${output_dir}/sa.pub" >/dev/null 2>&1; then
    log::error "Failed to generate Service Account public key"
    return 1
  fi

  # 设置权限
  chmod 600 "${output_dir}/sa.key"
  chmod 644 "${output_dir}/sa.pub"

  log::success "Service Account keypair generated successfully"
  return 0
}

#######################################
# 生成通用客户端证书
# Arguments:
#   $1 - 输出目录
#   $2 - CA目录 (含 ca.crt/ca-key.pem)
#   $3 - 证书名称前缀
#   $4 - Subject (如 /CN=system:kube-scheduler)
#   $5 - 扩展用途 (clientAuth|serverAuth,clientAuth)
#   $6 - SAN (可选, 逗号分隔: DNS:xx,IP:xx)
# Returns:
#   0 on success, 1 on failure
#######################################
pki::generate_client_cert() {
  local output_dir="$1"
  local ca_dir="$2"
  local name="$3"
  local subject="$4"
  local usage="${5:-clientAuth}"
  local sans="${6:-}"

  mkdir -p "${output_dir}"

  local key_file="${output_dir}/${name}.key"
  local csr_file="${output_dir}/${name}.csr"
  local crt_file="${output_dir}/${name}.crt"
  local ext_file="${output_dir}/${name}-ext.cnf"

  if ! openssl genrsa -out "${key_file}" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate key for ${name}"
    return 1
  fi

  if [[ -n "${sans}" ]]; then
    cat > "${ext_file}" << EOF
[ req ]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = ${usage}
subjectAltName = ${sans}
EOF
    if ! openssl req -new -key "${key_file}" \
      -out "${csr_file}" \
      -subj "${subject}" \
      -config "${ext_file}" >/dev/null 2>&1; then
      log::error "Failed to generate CSR for ${name}"
      return 1
    fi

    if ! openssl x509 -req -in "${csr_file}" \
      -CA "${ca_dir}/ca.crt" \
      -CAkey "${ca_dir}/ca-key.pem" \
      -CAcreateserial \
      -out "${crt_file}" \
      -extensions v3_req \
      -extfile "${ext_file}" -days 3650 >/dev/null 2>&1; then
      log::error "Failed to sign cert for ${name}"
      return 1
    fi
  else
    cat > "${ext_file}" << EOF
[ client_auth ]
extendedKeyUsage = ${usage}
EOF
    if ! openssl req -new -key "${key_file}" \
      -out "${csr_file}" \
      -subj "${subject}" >/dev/null 2>&1; then
      log::error "Failed to generate CSR for ${name}"
      return 1
    fi

    if ! openssl x509 -req -in "${csr_file}" \
      -CA "${ca_dir}/ca.crt" \
      -CAkey "${ca_dir}/ca-key.pem" \
      -CAcreateserial \
      -out "${crt_file}" \
      -extensions client_auth \
      -extfile "${ext_file}" -days 3650 >/dev/null 2>&1; then
      log::error "Failed to sign cert for ${name}"
      return 1
    fi
  fi

  chmod 600 "${key_file}"
  chmod 644 "${crt_file}"
  rm -f "${csr_file}" "${ext_file}"
  return 0
}

#######################################
# 生成控制平面/节点相关证书
#######################################
pki::generate_kubernetes_clients() {
  local output_dir="$1"
  local node_name="$2"
  local node_ip="$3"

  # apiserver-kubelet-client (clientAuth)
  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "apiserver-kubelet-client" "/CN=kube-apiserver-kubelet-client/O=system:masters" "clientAuth"

  # controller-manager (clientAuth)
  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "controller-manager" "/CN=system:kube-controller-manager" "clientAuth"

  # scheduler (clientAuth)
  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "scheduler" "/CN=system:kube-scheduler" "clientAuth"

  # kube-proxy (clientAuth)
  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "kube-proxy" "/CN=system:kube-proxy" "clientAuth"

  # kubelet (clientAuth,serverAuth) with SANs
  local sans="DNS:${node_name},IP:${node_ip}"
  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "kubelet" "/CN=system:node:${node_name}/O=system:nodes" "serverAuth,clientAuth" "${sans}"
}

#######################################
# 仅生成节点必需证书（kubelet + kube-proxy）
#######################################
pki::generate_node_clients() {
  local output_dir="$1"
  local node_name="$2"
  local node_ip="$3"

  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "kube-proxy" "/CN=system:kube-proxy" "clientAuth"

  local sans="DNS:${node_name},IP:${node_ip}"
  pki::generate_client_cert "${output_dir}" "${output_dir}" \
    "kubelet" "/CN=system:node:${node_name}/O=system:nodes" "serverAuth,clientAuth" "${sans}"
}

# ==============================================================================
# 证书续期
# ==============================================================================

#######################################
# 检查证书有效期
#######################################
pki::check_cert_expiry() {
  local cert_file="$1"
  local warn_days="${2:-$(defaults::get_cert_renew_days_before)}"

  if [[ ! -f "${cert_file}" ]]; then
    log::error "Certificate file not found: ${cert_file}"
    return 1
  fi

  local expiry_date=$(openssl x509 -enddate -noout -in "${cert_file}" | cut -d= -f2)
  local expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null)
  local current_epoch=$(date +%s)
  local days_left=$(( (expiry_epoch - current_epoch) / 86400 ))

  echo "${days_left}"
}

#######################################
# 续期CA证书
#######################################
pki::renew_ca() {
  local output_dir="$1"
  local ca_file="${output_dir}/ca.crt"

  log::info "Renewing CA certificate..."

  # 检查证书是否需要续期
  local days_left=$(pki::check_cert_expiry "${ca_file}")
  if [[ ${days_left} -gt 30 ]]; then
    log::info "CA certificate is still valid for ${days_left} days, skipping renewal"
    return 0
  fi

  log::info "CA certificate expires in ${days_left} days, renewing..."

  # 备份旧证书
  if [[ -f "${ca_file}" ]]; then
    cp "${ca_file}" "${ca_file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "${output_dir}/ca-key.pem" "${output_dir}/ca-key.pem.bak.$(date +%Y%m%d-%H%M%S)"
  fi

  # 重新生成CA证书
  pki::generate_ca "${output_dir}"

  log::info "CA certificate renewed successfully"
}

#######################################
# 续期所有证书
#######################################
pki::renew_all() {
  local output_dir="$1"
  local cluster_domain="$2"
  local api_servers="$3"

  log::info "Renewing all certificates..."

  # 续期CA证书
  pki::renew_ca "${output_dir}"

  # 重新生成组件证书
  pki::apiserver::generate_all "${output_dir}" "${cluster_domain}" "${api_servers}"
  pki::front_proxy::generate_all "${output_dir}"
  pki::sa::generate_keypair "${output_dir}"

  log::success "All certificates renewed successfully"
}

# ==============================================================================
# 证书验证
# ==============================================================================

#######################################
# 验证证书有效性
#######################################
pki::verify_cert() {
  local cert_file="$1"

  if [[ ! -f "${cert_file}" ]]; then
    log::error "Certificate file not found: ${cert_file}"
    return 1
  fi

  # 检查证书格式
  if ! openssl x509 -in "${cert_file}" -noout -text &>/dev/null; then
    log::error "Invalid certificate format: ${cert_file}"
    return 1
  fi

  # 显示证书信息
  log::info "Certificate: ${cert_file}"
  openssl x509 -in "${cert_file}" -noout -subject -dates

  return 0
}

#######################################
# 验证证书链
#######################################
pki::verify_cert_chain() {
  local cert_file="$1"
  local ca_file="$2"

  if [[ ! -f "${cert_file}" ]] || [[ ! -f "${ca_file}" ]]; then
    log::error "Certificate or CA file not found"
    return 1
  fi

  # 验证证书链
  if openssl verify -CAfile "${ca_file}" "${cert_file}" &>/dev/null; then
    log::info "Certificate chain is valid"
    return 0
  else
    log::error "Certificate chain verification failed"
    return 1
  fi
}

#######################################
# 生成etcd证书
#######################################
pki::etcd::generate_all() {
  local output_dir="$1"
  local etcd_ca_dir="$2"
  local etcd_nodes="$3"

  log::info "Generating etcd certificates..."

  mkdir -p "${output_dir}"

  # 生成etcd CA
  if [[ ! -f "${etcd_ca_dir}/ca.crt" ]]; then
    pki::generate_ca "${etcd_ca_dir}"
  fi

  # 生成etcd服务器证书
  local san_config="/tmp/etcd-san.cnf"
  cat > "${san_config}" << EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
EOF

  # 添加节点IP和DNS
  local counter=1
  for node in ${etcd_nodes}; do
    local node_ip=$(echo "${node}" | cut -d',' -f1)
    echo "IP.${counter} = ${node_ip}" >> "${san_config}"
    ((counter++)) || true
  done

  # 生成服务器证书
  if ! openssl genrsa -out "${output_dir}/server-key.pem" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate etcd server private key"
    return 1
  fi
  # 兼容常用命名
  cp "${output_dir}/server-key.pem" "${output_dir}/server.key"

  if ! openssl req -new -key "${output_dir}/server-key.pem" \
    -out "${output_dir}/server.csr" \
    -subj "/CN=etcd" \
    -config "${san_config}" >/dev/null 2>&1; then
    log::error "Failed to generate etcd server CSR"
    return 1
  fi

  if ! openssl x509 -req -in "${output_dir}/server.csr" \
    -CA "${etcd_ca_dir}/ca.crt" \
    -CAkey "${etcd_ca_dir}/ca-key.pem" \
    -CAcreateserial \
    -out "${output_dir}/server.crt" \
    -extensions v3_req \
    -extfile "${san_config}" -days 3650 >/dev/null 2>&1; then
    log::error "Failed to sign etcd server certificate"
    return 1
  fi

  # 生成对等证书
  if ! openssl genrsa -out "${output_dir}/peer-key.pem" 2048 >/dev/null 2>&1; then
    log::error "Failed to generate etcd peer private key"
    return 1
  fi
  # 兼容常用命名
  cp "${output_dir}/peer-key.pem" "${output_dir}/peer.key"

  if ! openssl req -new -key "${output_dir}/peer-key.pem" \
    -out "${output_dir}/peer.csr" \
    -subj "/CN=etcd-peer" \
    -config "${san_config}" >/dev/null 2>&1; then
    log::error "Failed to generate etcd peer CSR"
    return 1
  fi

  if ! openssl x509 -req -in "${output_dir}/peer.csr" \
    -CA "${etcd_ca_dir}/ca.crt" \
    -CAkey "${etcd_ca_dir}/ca-key.pem" \
    -CAcreateserial \
    -out "${output_dir}/peer.crt" \
    -extensions v3_req \
    -extfile "${san_config}" -days 3650 >/dev/null 2>&1; then
    log::error "Failed to sign etcd peer certificate"
    return 1
  fi

  # 设置权限
  chmod 600 "${output_dir}/server-key.pem" "${output_dir}/peer-key.pem" "${output_dir}/server.key" "${output_dir}/peer.key"
  chmod 644 "${output_dir}/server.crt" "${output_dir}/peer.crt"

  # 清理临时文件
  rm -f "${san_config}" "${output_dir}/server.csr" "${output_dir}/peer.csr"

  # 生成健康检查与apiserver客户端证书
  pki::generate_client_cert "${output_dir}" "${etcd_ca_dir}" \
    "healthcheck-client" "/CN=kube-etcd-healthcheck-client/O=system:masters" "clientAuth"
  pki::generate_client_cert "${output_dir}" "${etcd_ca_dir}" \
    "apiserver-etcd-client" "/CN=kube-apiserver-etcd-client/O=system:masters" "clientAuth"

  log::success "etcd certificates generated successfully"
  return 0
}

# ==============================================================================
# 初始化完整PKI证书体系
# ==============================================================================

#######################################
# 初始化完整PKI证书体系
#######################################
pki::init_pki() {
  local output_dir="$1"
  local cluster_domain="$2"
  local api_servers="$3"
  local etcd_nodes="$4"

  log::info "Initializing PKI certificate system..."

  # 生成CA证书
  pki::generate_ca "${output_dir}"

  # 生成组件证书
  pki::apiserver::generate_all "${output_dir}" "${cluster_domain}" "${api_servers}"
  pki::front_proxy::generate_all "${output_dir}"
  pki::sa::generate_keypair "${output_dir}"

  # 生成etcd证书
  pki::etcd::generate_all "${output_dir}/etcd" "${output_dir}" "${etcd_nodes}"

  log::success "PKI certificate system initialized successfully"
}

# 导出函数
export -f pki::generate_ca
export -f pki::apiserver::generate_all
export -f pki::front_proxy::generate_all
export -f pki::sa::generate_keypair
export -f pki::generate_client_cert
export -f pki::generate_kubernetes_clients
export -f pki::generate_node_clients
export -f pki::check_cert_expiry
export -f pki::renew_ca
export -f pki::renew_all
export -f pki::verify_cert
export -f pki::verify_cert_chain
export -f pki::etcd::generate_all
export -f pki::init_pki
