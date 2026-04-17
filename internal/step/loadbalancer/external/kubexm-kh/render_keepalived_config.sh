#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kh.render.keepalived.config::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local lb_dir
  lb_dir="$(context::get "lb_kh_keepalived_dir" || true)"
  if [[ -n "${lb_dir}" && -f "${lb_dir}/keepalived.conf" ]]; then
    return 0
  fi
  return 1
}

step::lb.external.kubexm.kh.render.keepalived.config::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"

  local lb_dir vip interface state priority node_index router_id auth_pass unicast_peers
  lb_dir="$(context::get "lb_kh_keepalived_dir" || true)"
  vip="$(context::get "lb_kh_keepalived_vip" || true)"
  interface="$(context::get "lb_kh_keepalived_interface" || true)"
  state="$(context::get "lb_kh_keepalived_state" || true)"
  priority="$(context::get "lb_kh_keepalived_priority" || true)"
  node_index="$(context::get "lb_kh_keepalived_node_index" || true)"
  router_id="$(context::get "lb_kh_keepalived_router_id" || echo "50")"
  auth_pass="$(context::get "lb_kh_keepalived_auth_pass" || echo "KUBEXM_AUTH_$(echo "${KUBEXM_CLUSTER_NAME:-default}" | md5sum | cut -c1-8)")"
  unicast_peers="$(context::get "lb_kh_keepalived_unicast_peers" || true)"

  local keepalived_cfg
  keepalived_cfg="! Configuration File for keepalived
global_defs {
  router_id KUBEXM_LB_${node_index}
  enable_script_security
  script_user root
}
vrrp_script check_haproxy {
  script \"/etc/keepalived/check_haproxy.sh\"
  interval 2
  weight 2
  fall 2
  rise 2
}
vrrp_instance VI_KUBE {
  state ${state}
  interface ${interface}
  virtual_router_id ${router_id}
  priority ${priority}
  advert_int 1
  unicast_src_ip \$(hostname -I | awk '{print \$1}')
  unicast_peer {
$(echo "${unicast_peers}" | sed '/^$/d')
  }
  authentication {
    auth_type PASS
    auth_pass ${auth_pass}
  }
  virtual_ipaddress {
    ${vip}
  }
  track_script {
    check_haproxy
  }
  nopreempt
}"

  printf '%s\n' "${keepalived_cfg}" > "${lb_dir}/keepalived.conf"
}

step::lb.external.kubexm.kh.render.keepalived.config::rollback() { return 0; }

step::lb.external.kubexm.kh.render.keepalived.config::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
