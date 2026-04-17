#!/bin/bash
# =============================================================================
# KubeXM Script - 24 Deployment Scenarios Logic
# =============================================================================
# Purpose: Handle conditional logic for all 24 deployment scenarios
# Format: k8s_type-etcd_type-lb_mode-lb_type
# =============================================================================

set -euo pipefail

# Get script directory
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

# All 24 deployment scenarios
declare -a ALL_SCENARIOS=(
  # kubeadm + stacked etcd (6 scenarios)
  "kubeadm-stacked-none-none"
  "kubeadm-stacked-internal-haproxy"
  "kubeadm-stacked-internal-nginx"
  "kubeadm-stacked-external-haproxy"
  "kubeadm-stacked-external-nginx"
  "kubeadm-stacked-kube-vip-none"

  # kubeadm + external etcd (6 scenarios)
  "kubeadm-external-none-none"
  "kubeadm-external-internal-haproxy"
  "kubeadm-external-internal-nginx"
  "kubeadm-external-external-haproxy"
  "kubeadm-external-external-nginx"
  "kubeadm-external-kube-vip-none"

  # kubexm + stacked etcd (6 scenarios)
  "kubexm-stacked-none-none"
  "kubexm-stacked-internal-haproxy"
  "kubexm-stacked-internal-nginx"
  "kubexm-stacked-external-haproxy"
  "kubexm-stacked-external-nginx"
  "kubexm-stacked-kube-vip-none"

  # kubexm + external etcd (6 scenarios)
  "kubexm-external-none-none"
  "kubexm-external-internal-haproxy"
  "kubexm-external-internal-nginx"
  "kubexm-external-external-haproxy"
  "kubexm-external-external-nginx"
  "kubexm-external-kube-vip-none"
)

# Package mappings for each scenario
declare -A SCENARIO_PACKAGES

# Image mappings for each scenario
declare -A SCENARIO_IMAGES

# Binary mappings for each scenario
declare -A SCENARIO_BINARIES

# -----------------------------------------------------------------------------
# Scenario Parsing Functions
# -----------------------------------------------------------------------------

# Parse scenario string into components
scenario::parse() {
  local scenario="$1"
  local IFS='-'

  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  echo "${k8s_type}|${etcd_type}|${lb_mode}|${lb_type}"
}

# Validate scenario format
scenario::validate() {
  local scenario="$1"

  # Check full schema (supports hyphenated kube-vip token)
  if [[ "${scenario}" =~ ^(kubeadm|kubexm)-(stacked|external)-(none|internal|external|kube-vip)-(none|haproxy|nginx|kube-vip|existing)$ ]]; then
    return 0
  fi

  return 1
}

# List all valid scenarios
scenario::list_all() {
  printf '%s\n' "${ALL_SCENARIOS[@]}"
}

# Check if scenario is valid
scenario::is_valid() {
  local scenario="$1"

  for valid_scenario in "${ALL_SCENARIOS[@]}"; do
    if [[ "${scenario}" == "${valid_scenario}" ]]; then
      return 0
    fi
  done

  return 1
}

# -----------------------------------------------------------------------------
# Package Selection Logic
# -----------------------------------------------------------------------------

# Get required packages for a scenario
scenario::get_packages() {
  local scenario="$1"

  if ! scenario::is_valid "${scenario}"; then
    echo "ERROR: Invalid scenario: ${scenario}" >&2
    return 1
  fi

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local packages=()

  # Base packages (always required)
  packages+=(
    "curl"
    "wget"
    "conntrack"
    "socat"
    "ethtool"
    "iproute"
    "ipset"
    "ipvsadm"
    "iptables"
    "ebtables"
  )

  # Container runtime packages (kubexm only)
  if [[ "${k8s_type}" == "kubexm" ]]; then
    packages+=(
      "containerd.io"
      "runc"
    )
  fi

  # LoadBalancer packages
  case "${lb_mode}" in
    internal)
      case "${lb_type}" in
        haproxy)
          packages+=("haproxy")
          ;;
        nginx)
          packages+=("nginx")
          ;;
      esac
      ;;
    external)
      case "${lb_type}" in
        haproxy)
          packages+=("haproxy" "keepalived")
          ;;
        nginx)
          packages+=("nginx" "keepalived")
          ;;
      esac
      ;;
  esac

  # Network plugins (based on package manager)
  case "${lb_type}" in
    *)
      # Additional packages might be needed
      ;;
  esac

  printf '%s\n' "${packages[@]}" | sort -u
}

# Get RPM-specific packages
scenario::get_rpm_packages() {
  local scenario="$1"
  local packages=($(scenario::get_packages "${scenario}"))

  # Convert to RPM package names
  local rpm_packages=()
  for pkg in "${packages[@]}"; do
    case "${pkg}" in
      conntrack)
        rpm_packages+=("conntrack-tools")
        ;;
      iproute)
        rpm_packages+=("iproute")
        ;;
      *)
        rpm_packages+=("${pkg}")
        ;;
    esac
  done

  printf '%s\n' "${rpm_packages[@]}" | sort -u
}

# Get DEB-specific packages
scenario::get_deb_packages() {
  local scenario="$1"
  local packages=($(scenario::get_packages "${scenario}"))

  # Convert to DEB package names
  local deb_packages=()
  for pkg in "${packages[@]}"; do
    case "${pkg}" in
      conntrack)
        deb_packages+=("conntrack")
        ;;
      iproute)
        deb_packages+=("iproute2")
        ;;
      *)
        deb_packages+=("${pkg}")
        ;;
    esac
  done

  printf '%s\n' "${deb_packages[@]}" | sort -u
}

# -----------------------------------------------------------------------------
# Image Selection Logic
# -----------------------------------------------------------------------------

# Get required container images for a scenario
scenario::get_images() {
  local scenario="$1"

  if ! scenario::is_valid "${scenario}"; then
    echo "ERROR: Invalid scenario: ${scenario}" >&2
    return 1
  fi

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local images=()

  # Pause image (always needed)
  images+=("registry.k8s.io/pause:3.10")

  # CoreDNS (always needed)
  local coredns_version
  coredns_version=$(defaults::get_coredns_version 2>/dev/null || echo "v1.11.1")
  images+=("registry.k8s.io/coredns/coredns:${coredns_version}")

  # Control plane images (kubeadm only)
  if [[ "${k8s_type}" == "kubeadm" ]]; then
    images+=(
      "registry.k8s.io/kube-apiserver"
      "registry.k8s.io/kube-controller-manager"
      "registry.k8s.io/kube-scheduler"
      "registry.k8s.io/kube-proxy"
    )

    # etcd image (stacked only)
    if [[ "${etcd_type}" == "stacked" ]]; then
      local etcd_version
      etcd_version=$(defaults::get_etcd_version 2>/dev/null || echo "3.5.10-0")
      images+=("registry.k8s.io/etcd:${etcd_version}")
    fi
  fi

  # LoadBalancer images
  case "${lb_mode}" in
    internal)
      case "${lb_type}" in
        haproxy)
          images+=("haproxy:2.8-alpine")
          ;;
        nginx)
          images+=("nginx:1.25-alpine")
          ;;
      esac
      ;;
    kube-vip)
      local kube_vip_version
      kube_vip_version=$(defaults::get_kubevip_version 2>/dev/null || echo "v0.8.0")
      images+=("ghcr.io/kube-vip/kube-vip:${kube_vip_version}")
      ;;
  esac

  printf '%s\n' "${images[@]}" | sort -u
}

# -----------------------------------------------------------------------------
# Binary Selection Logic
# -----------------------------------------------------------------------------

# Get required binaries for a scenario
scenario::get_binaries() {
  local scenario="$1"

  if ! scenario::is_valid "${scenario}"; then
    echo "ERROR: Invalid scenario: ${scenario}" >&2
    return 1
  fi

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local binaries=()

  # Base binaries
  binaries+=(
    "kubectl"
    "crictl"
  )

  # Kubernetes binaries based on type
  case "${k8s_type}" in
    kubeadm)
      binaries+=(
        "kubeadm"
        "kubelet"
      )
      ;;
    kubexm)
      binaries+=(
        "kube-apiserver"
        "kube-controller-manager"
        "kube-scheduler"
        "kubelet"
        "kube-proxy"
      )
      ;;
  esac

  # Container runtime binaries
  case "${k8s_type}" in
    kubexm)
      binaries+=(
        "containerd"
        "containerd-shim"
        "containerd-shim-runc-v2"
        "runc"
      )
      ;;
  esac

  # etcd binaries (kubexm + external etcd)
  if [[ "${k8s_type}" == "kubexm" && "${etcd_type}" == "external" ]]; then
    binaries+=(
      "etcd"
      "etcdctl"
    )
  fi

  printf '%s\n' "${binaries[@]}" | sort -u
}

# -----------------------------------------------------------------------------
# Scenario Classification
# -----------------------------------------------------------------------------

# Get scenario category
scenario::get_category() {
  local scenario="$1"

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  echo "${k8s_type}-${etcd_type}-${lb_mode}"
}

# Get scenario description
scenario::get_description() {
  local scenario="$1"

  if ! scenario::is_valid "${scenario}"; then
    echo "Invalid scenario"
    return
  fi

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local desc=""

  case "${k8s_type}" in
    kubeadm) desc+="Kubeadm模式, " ;;
    kubexm)  desc+="Kubexm二进制模式, " ;;
  esac

  case "${etcd_type}" in
    stacked)  desc+="堆叠etcd" ;;
    external) desc+="外部etcd" ;;
  esac

  desc+=", "

  case "${lb_mode}" in
    none)     desc+="无负载均衡" ;;
    internal) desc+="内部负载均衡 (${lb_type})" ;;
    external) desc+="外部负载均衡 (${lb_type})" ;;
    kube-vip) desc+="kube-vip负载均衡" ;;
  esac

  echo "${desc}"
}

# Get scenario complexity (1-5 scale)
scenario::get_complexity() {
  local scenario="$1"

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local complexity=1

  # Kubernetes type
  case "${k8s_type}" in
    kubexm)  ((complexity++)) || true ;;
  esac

  # etcd type
  case "${etcd_type}" in
    external) ((complexity++)) || true ;;
  esac

  # LoadBalancer mode
  case "${lb_mode}" in
    external) ((complexity++)) || true ;;
    kube-vip) ((complexity++)) || true ;;
  esac

  # LoadBalancer type
  case "${lb_type}" in
    haproxy|nginx) ((complexity++)) || true ;;
  esac

  echo "${complexity}"
}

# -----------------------------------------------------------------------------
# Scenario Comparison
# -----------------------------------------------------------------------------

# Compare two scenarios
scenario::compare() {
  local scenario1="$1"
  local scenario2="$2"

  local comp1=$(scenario::get_complexity "${scenario1}")
  local comp2=$(scenario::get_complexity "${scenario2}")

  if [[ ${comp1} -lt ${comp2} ]]; then
    echo "less"
  elif [[ ${comp1} -gt ${comp2} ]]; then
    echo "greater"
  else
    echo "equal"
  fi
}

# Find scenarios with similar configuration
scenario::find_similar() {
  local scenario="$1"
  local threshold="${2:-2}"

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local similar=()

  for test_scenario in "${ALL_SCENARIOS[@]}"; do
    [[ "${test_scenario}" == "${scenario}" ]] && continue

    local IFS='-'
    read -r t_k8s t_etcd t_lb_mode t_lb_type <<< "${test_scenario}"

    local diff=0
    [[ "${k8s_type}" != "${t_k8s}" ]] && ((diff++)) || true
    [[ "${etcd_type}" != "${t_etcd}" ]] && ((diff++)) || true
    [[ "${lb_mode}" != "${t_lb_mode}" ]] && ((diff++)) || true
    [[ "${lb_type}" != "${t_lb_type}" ]] && ((diff++)) || true

    if [[ ${diff} -le ${threshold} ]]; then
      similar+=("${test_scenario}")
    fi
  done

  printf '%s\n' "${similar[@]}"
}

# -----------------------------------------------------------------------------
# Resource Calculation
# -----------------------------------------------------------------------------

# Calculate estimated resource requirements
scenario::calculate_resources() {
  local scenario="$1"

  if ! scenario::is_valid "${scenario}"; then
    echo "ERROR: Invalid scenario: ${scenario}" >&2
    return 1
  fi

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  # Base resource requirements
  local cpu_cores=2
  local memory_gb=4
  local disk_gb=20

  # Adjust based on k8s type
  case "${k8s_type}" in
    kubexm)
      ((cpu_cores+=1))
      ((memory_gb+=2))
      ((disk_gb+=5))
      ;;
  esac

  # Adjust based on etcd type
  case "${etcd_type}" in
    external)
      ((cpu_cores+=1))
      ((memory_gb+=1))
      ((disk_gb+=10))
      ;;
  esac

  # Adjust based on LoadBalancer
  case "${lb_mode}" in
    external)
      ((cpu_cores+=1))
      ((memory_gb+=1))
      ((disk_gb+=2))
      ;;
    internal)
      memory_gb=$(awk "BEGIN {print ${memory_gb} + 0.5}")
      ;;
  esac

  echo "${cpu_cores}|${memory_gb}|${disk_gb}"
}

# -----------------------------------------------------------------------------
# Scenario Testing
# -----------------------------------------------------------------------------

# Generate test cases for a scenario
scenario::generate_tests() {
  local scenario="$1"

  if ! scenario::is_valid "${scenario}"; then
    echo "ERROR: Invalid scenario: ${scenario}" >&2
    return 1
  fi

  local IFS='-'
  read -r k8s_type etcd_type lb_mode lb_type <<< "${scenario}"

  local tests=()

  # Basic functionality tests
  tests+=("test_${scenario//-/_}_basic")

  # Package installation tests
  tests+=("test_${scenario//-/_}_packages")

  # Binary installation tests
  tests+=("test_${scenario//-/_}_binaries")

  # Image loading tests
  tests+=("test_${scenario//-/_}_images")

  # Configuration tests
  tests+=("test_${scenario//-/_}_config")

  printf '%s\n' "${tests[@]}"
}

# -----------------------------------------------------------------------------
# Scenario Documentation
# -----------------------------------------------------------------------------

# Generate scenario documentation
scenario::generate_docs() {
  local output_file="$1"

  cat > "${output_file}" << 'EOF'
# KubeXM Deployment Scenarios Documentation

## Overview

KubeXM supports 24 different deployment scenarios, defined by:
- **Kubernetes Type**: kubeadm (containerized) or kubexm (binary)
- **etcd Type**: stacked (with k8s) or external (separate cluster)
- **LoadBalancer Mode**: none, internal, external, or kube-vip
- **LoadBalancer Type**: haproxy, nginx, kube-vip, or existing

## Scenario Format

Format: `k8s_type-etcd_type-lb_mode-lb_type`

Example: `kubexm-external-external-haproxy`

## All Scenarios

EOF

  for scenario in "${ALL_SCENARIOS[@]}"; do
    local desc=$(scenario::get_description "${scenario}")
    local complexity=$(scenario::get_complexity "${scenario}")

    echo "### ${scenario}" >> "${output_file}"
    echo "" >> "${output_file}"
    echo "**Description**: ${desc}" >> "${output_file}"
    echo "" >> "${output_file}"
    echo "**Complexity**: ${complexity}/5" >> "${output_file}"
    echo "" >> "${output_file}"

    # Packages
    echo "**Required Packages**:" >> "${output_file}"
    scenario::get_packages "${scenario}" | while read -r pkg; do
      echo "- ${pkg}" >> "${output_file}"
    done
    echo "" >> "${output_file}"

    # Images
    echo "**Container Images**:" >> "${output_file}"
    scenario::get_images "${scenario}" | while read -r img; do
      echo "- ${img}" >> "${output_file}"
    done
    echo "" >> "${output_file}"

    # Binaries
    echo "**Binaries**:" >> "${output_file}"
    scenario::get_binaries "${scenario}" | while read -r bin; do
      echo "- ${bin}" >> "${output_file}"
    done
    echo "" >> "${output_file}"

    echo "---" >> "${output_file}"
    echo "" >> "${output_file}"
  done

  cat >> "${output_file}" << 'EOF'

## Quick Reference

### By Complexity

**Simple (1-2)**: kubeadm-stacked-none-none
**Moderate (3)**: kubeadm-external-none-none, kubexm-stacked-none-none
**Complex (4)**: kubexm-external-none-none, kubexm-stacked-external-haproxy
**Very Complex (5)**: kubexm-external-external-haproxy, kubexm-external-kube-vip-none

### By Use Case

**Development/Testing**:
- kubeadm-stacked-none-none
- kubexm-stacked-none-none

**Production - Internal LB**:
- kubeadm-stacked-internal-haproxy
- kubexm-stacked-internal-nginx

**Production - External LB**:
- kubeadm-external-external-haproxy
- kubexm-external-external-nginx

**High Availability**:
- kubeadm-external-kube-vip-none
- kubexm-external-kube-vip-none

## Recommendations

1. **Development**: Use `kubeadm-stacked-none-none` for simplicity
2. **Small Production**: Use `kubeadm-stacked-internal-haproxy` for good balance
3. **Medium Production**: Use `kubeadm-external-internal-nginx` for separation
4. **Large Production**: Use `kubexm-external-external-haproxy` for full control
5. **High Availability**: Use `kubexm-external-kube-vip-none` for VIP-based LB

EOF

  echo "Scenario documentation generated: ${output_file}"
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
scenario::main() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    list)
      scenario::list_all
      ;;
    validate)
      local scenario="${1:-}"
      if scenario::validate "${scenario}"; then
        echo "Valid: ${scenario}"
        exit 0
      else
        echo "Invalid: ${scenario}"
        exit 1
      fi
      ;;
    packages)
      local scenario="${1:-}"
      scenario::get_packages "${scenario}"
      ;;
    rpm-packages)
      local scenario="${1:-}"
      scenario::get_rpm_packages "${scenario}"
      ;;
    deb-packages)
      local scenario="${1:-}"
      scenario::get_deb_packages "${scenario}"
      ;;
    images)
      local scenario="${1:-}"
      scenario::get_images "${scenario}"
      ;;
    binaries)
      local scenario="${1:-}"
      scenario::get_binaries "${scenario}"
      ;;
    desc)
      local scenario="${1:-}"
      scenario::get_description "${scenario}"
      ;;
    complexity)
      local scenario="${1:-}"
      scenario::get_complexity "${scenario}"
      ;;
    category)
      local scenario="${1:-}"
      scenario::get_category "${scenario}"
      ;;
    similar)
      local scenario="${1:-}"
      local threshold="${2:-2}"
      scenario::find_similar "${scenario}" "${threshold}"
      ;;
    resources)
      local scenario="${1:-}"
      scenario::calculate_resources "${scenario}"
      ;;
    tests)
      local scenario="${1:-}"
      scenario::generate_tests "${scenario}"
      ;;
    docs)
      local output_file="${1:-/tmp/scenarios.md}"
      scenario::generate_docs "${output_file}"
      ;;
    help|--help|-h)
      cat << 'EOF'
KubeXM 24 Deployment Scenarios Handler

Usage: scenarios.sh <action> [options]

Actions:
  list                                  List all 24 scenarios
  validate <scenario>                   Validate scenario format
  packages <scenario>                   Get required packages
  rpm-packages <scenario>               Get RPM packages
  deb-packages <scenario>               Get DEB packages
  images <scenario>                     Get container images
  binaries <scenario>                   Get required binaries
  desc <scenario>                       Get scenario description
  complexity <scenario>                 Get complexity (1-5)
  category <scenario>                   Get scenario category
  similar <scenario> [threshold]        Find similar scenarios
  resources <scenario>                  Calculate resource requirements
  tests <scenario>                      Generate test cases
  docs [output_file]                    Generate documentation
  help                                  Show this help

Scenario Format: k8s_type-etcd_type-lb_mode-lb_type
Examples:
  kubeadm-stacked-none-none
  kubexm-external-external-haproxy
  kubeadm-stacked-internal-nginx

Examples:
  # List all scenarios
  scenarios.sh list

  # Get packages for a scenario
  scenarios.sh packages kubexm-external-external-haproxy

  # Generate documentation
  scenarios.sh docs /tmp/scenarios.md

  # Find similar scenarios
  scenarios.sh similar kubexm-stacked-internal-haproxy 1
EOF
      ;;
    *)
      echo "Unknown action: ${action}"
      echo "Use 'scenarios.sh help' for usage information"
      return 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  scenario::main "$@"
fi
