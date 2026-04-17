#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Utils Module (纯工具函数，无业务逻辑)
# ==============================================================================
# 职责：提供无状态的工具函数，供 Task/Step/Module 层调用
# 禁止：不得调用 runner/connector，不得有副作用（文件写入、网络操作等）
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 核心工具
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/common.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/retry.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/pipeline.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/template.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/identity.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/targets.sh"

# BOM (Bill of Materials) 管理
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/binary_bom.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/helm_bom.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/os_bom.sh"

# 配置渲染（纯函数，无副作用）
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/loadbalancer.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/haproxy.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/nginx.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/keepalived.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/kube-vip.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/etcd_render.sh"

# 离线验证
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/offline/validate_packages.sh"

log::debug "Utils module loaded successfully"
