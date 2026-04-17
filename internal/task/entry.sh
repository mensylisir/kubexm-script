#!/usr/bin/env bash
# ==============================================================================
# Task Layer - Entry Point
# ==============================================================================
# 所有 task 模块的统一加载入口
# ==============================================================================

# 公共 task 函数
source "${KUBEXM_ROOT}/internal/task/common.sh"

# 证书操作（业务逻辑，已从 utils 迁移）
source "${KUBEXM_ROOT}/internal/task/certs/pki.sh"
source "${KUBEXM_ROOT}/internal/task/certs/kubeconfig.sh"
source "${KUBEXM_ROOT}/internal/task/certs/node_certs.sh"
source "${KUBEXM_ROOT}/internal/task/certs/cert_rotation.sh"
source "${KUBEXM_ROOT}/internal/task/certs/certs_renew.sh"

# 镜像操作（业务逻辑，已从 utils 迁移）
source "${KUBEXM_ROOT}/internal/task/images/image.sh"
source "${KUBEXM_ROOT}/internal/task/images/image_manager.sh"
source "${KUBEXM_ROOT}/internal/task/images/image_push.sh"

# Helm 操作
source "${KUBEXM_ROOT}/internal/task/helm/helm_manager.sh"

# CNI 准备
source "${KUBEXM_ROOT}/internal/task/cni/prepare.sh"

# kubeadm 配置
source "${KUBEXM_ROOT}/internal/task/kubeadm/config.sh"

# 资源构建/下载
source "${KUBEXM_ROOT}/internal/task/resources/download.sh"
source "${KUBEXM_ROOT}/internal/task/resources/build_packages.sh"
source "${KUBEXM_ROOT}/internal/task/resources/build_iso.sh"
source "${KUBEXM_ROOT}/internal/task/resources/build_docker.sh"
source "${KUBEXM_ROOT}/internal/task/resources/system_iso.sh"

log::debug "Task module entry point loaded"
