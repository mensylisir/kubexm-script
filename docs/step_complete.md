# Kubernetes 集群部署完整流程指南

## 配置文件
### 机器清单文件
```
# host.yaml
apiVersion: kubexm.io/v1
kind: Host
metadata:
  name: sample
spec:
  hosts:
  - {name: node1, address: 172.30.1.13, internalAddress: 172.30.1.13, user: root, password: "Def@u1tpwd"}
  - {name: node2, address: 172.30.1.12, internalAddress: 172.30.1.12, user: root, password: "Def@u1tpwd"}
  - {name: node3, address: 172.30.1.14, internalAddress: 172.30.1.14, user: root, password: "Def@u1tpwd"}
  - {name: node4, address: 172.30.1.15, internalAddress: 172.30.1.15, user: root, password: "Def@u1tpwd"}
  - {name: node5, address: 172.30.1.16, internalAddress: 172.30.1.16, user: root, password: "Def@u1tpwd"}
  - {name: node7, address: 172.30.1.17, internalAddress: 172.30.1.17, user: root, password: "Def@u1tpwd"}
  - {name: node8, address: 172.30.1.18, internalAddress: 172.30.1.18, user: root, password: "Def@u1tpwd"}
  - {name: node9, address: 172.30.1.19, internalAddress: 172.30.1.19, user: root, password: "Def@u1tpwd"}
  roleGroups:
    etcd:
    - node2
    - node3
    - node4
    control-plane:
    - node2
    - node3
    - node4
    worker:
    - node2
    - node3
    - node4
    - node5
    - node7
    - node8
    - node9
    loadbalancer: []
    registry: []
```
### 参数配置文件
```
# config.yaml
apiVersion: kubexm.io/v1
kind: Config
metadata:
  name: config-sample
spec:
  mode: offline                       # 有online和offline两个取值，online表示在线部署，offline表示离线部署
  arch:
    - arm64
    - amd64
  kubernetes:
    type: kubeadm                     # 有kubeadm和kubexm两个取值，kubeadm表示kubeadm部署kubernetes，kubexm表示二进制部署kubernetes
    version: v1.32.4                  # Kubernetes 版本 (支持 v1.24 - v1.34)
    service_cidr: 10.96.0.0/12        # Service网络
    pod_cidr: 10.244.0.0/16           # Pod网络
    cluster_domain: cluster.local     # DNS域名
    # dns_service_ip: 10.96.0.10      # DNS Service IP，这个不需要配置，代码自动计算，如果启用了nodelocaldns
    autoRenewCerts: true              # 自动续期kubernetes叶子结点

    apiserver:
      advertise_address: ""           # API Server 绑定地址 自动检测
      secure_port: 6443               # API Server 端口
      audit:
        enabled: true
        log_path: /var/log/kubernetes/audit.log
        log_maxage: 30
        log_maxbackup: 10
        log_maxsize: 100
        policy_file: "/etc/kubernetes/audit-policy.yaml"
        policy:
          rules:
            - level: None
              omitStages:
                - "RequestReceived"
            - level: None
              users: ["system:kube-proxy", "system:apiserver", "system:controller-manager", "system:scheduler"]
              verbs: ["watch"]
              resources:
                - group: ""
                  resources: ["endpoints", "services", "services/status"]
            - level: Metadata
              resources:
                - group: ""
                  resources: ["secrets", "configmaps", "serviceaccounts/token"]
            - level: RequestResponse
              verbs: ["create", "update", "patch", "delete", "deletecollection"]
            - level: Metadata
              verbs: ["get", "list", "watch"]
      extra_args: []
    controller_manager:
      allocate_node_cidrs: true
      node_cidr_mask_size: 24

    kube_proxy:
      mode: ipvs              # iptables | ipvs
      strict_arp: false        # 是否开启 strict ARP (对于 MetalLB 或 Kube-vip 必须)

  etcd:
    type: kubeadm                   # 部署类型: kubeadm(容器化) | kubexm(二进制)
    version: v3.5.13                # 一般不指定，走默认值
    mode: stacked                   # 部署模式: stacked(堆叠) | external(外置)
    data_dir: /var/lib/etcd         # 数据目录
    autoBackupEtcd: true            # 自动备份etcd
    extra_args:                     # 如果配置了额外参数，则要设置
      quota-backend-bytes: "8589934592"  # 8GB
      snapshot-count: "100000"
      heartbeat-interval: "250"
      election-timeout: "2500"
      auto-compaction-retention: "1"
      auto-compaction-mode: "periodic"
      max-request-bytes: "10485760"

  runtime:
    type: containerd                  # containerd | docker | crio | podman
    version: v1.7.13                  # 运行时的版本 (对应下面选中的那个类型)
    cgroup_driver: systemd            # 强烈建议 systemd
    data_dir: /var/lib/containerd     # 数据根目录 (根据 type 不同，代码里映射到不同路径)
    registry:
      mirrors:
        - registry: docker.io
          endpoint: https://docker.mirrors.ustc.edu.cn
        - registry: registry.k8s.io
          endpoint: https://registry.aliyuncs.com/google_containers

    insecure_registries:              # HTTP 仓库白名单
      - "192.168.1.0/24"
      - "harbor.internal"

    containerd:
      run_dir: "/run/containerd"
      config_path: "/etc/containerd/config.toml"
      max_container_log_line_size: 16384

    docker:
      cri_dockerd:
        enabled: true
        version: v0.3.10              # cri-dockerd 的版本

      daemon_json:
        live_restore: true            # 生产环境必备：daemon 重启不杀容器
        log_driver: "json-file"       # 日志驱动
        log_opts:
          max-size: "100m"            # 单文件大小
          max-file: "5"               # 保留文件数
        storage_driver: "overlay2"

    crio:
      # [注意] CRI-O 的主版本号必须与 K8s 保持一致 (如 k8s 1.28 -> crio 1.28)
      # 配置文件路径: /etc/crio/crio.conf
      # 监控工具 conmon 的路径 (一般自动检测，但支持指定)
      conmon_path: ""
      # 容器进程数限制
      pids_limit: 1024
      # 日志级别: fatal, panic, error, warn, info, debug
      log_level: info

    podman:
      # 配置文件: /etc/containers/storage.conf
      storage_driver: "overlay"
      rootless: false                 # 是否开启无根模式 (K8s 一般需要 root)
      events_logger: "file"           # journald | file

  network:
    plugin: calico
    interface: "eth.*"
    ip_family: ipv4

    node_cidr_mask_size: 24   # 这是一个全局抽象参数，代码根据 plugin 类型决定填到哪里

    calico:
      version: v3.27.0
      mode: ipip
      # Calico 内部叫 blockSize
      # 如果上面的 node_cidr_mask_size 设置了，这里默认继承
      # 但 Calico 允许更灵活的分配，比如设置为 26 (按需分配小块)
      block_size: 26

    flannel:
      version: v0.24.0
      backend: vxlan
      # Flannel 没有自己的 block配置，它完全依赖 kubernetes.controller_manager.node_cidr_mask_size

    cilium:
      version: v1.14.5
      tunnel_mode: vxlan
      # Cilium 的 IPAM 模式:
      # - kubernetes: 使用 k8s 分配 (依赖 controller manager)
      # - cluster-pool: Cilium 自己分配 (推荐，性能好，分配快)
      ipam_mode: cluster-pool

      # 仅在 ipam_mode: cluster-pool 时生效
      # 对应 cilium 配置中的 ipv4-node-cidr-mask-size
      cidr_mask_size: 24

  loadbalancer:
    enabled: true
    mode: external            # 模式选择: internal | external | kube-vip
    # 负载均衡器类型
    # internal 模式下: haproxy | nginx
    # external 模式下: kubexm-kh (Keepalived+HAProxy) | kubexm-kn (Keepalived+Nginx) | existing (现有的硬件LB)
    type: kubexm-kh
    # VIP 地址 (external 和 kube-vip 模式必填)
    vip: 192.168.1.100

    # 绑定网卡 (Keepalived 和 kube-vip 可以选填，如果节点有多张网卡建议填写，如果单张网卡则程序自动检测)
    interface: eth0


    internal:
      # HAProxy 特定配置 (当 type=haproxy)
      haproxy:
        bind_port: 6443             # 监听本地端口
        # 后端服务器列表通常由安装程序自动根据 Master 节点生成，无需手动配置

      # Nginx 特定配置 (当 type=nginx)
      nginx:
        bind_port: 6443

    external:
      # Keepalived 配置 (用于 kubexm-kh 和 kubexm-kn)
      keepalived:
        router_id: 51               # VRRP 路由 ID
        priority: 100               # 初始优先级
        auth_pass: "kubexm_pass"    # 认证密码

      # HAProxy 配置 (用于 kubexm-kh)
      haproxy:
        stats_port: 9000
        stats_user: admin
        stats_password: admin

      # Nginx 配置 (用于 kubexm-kn)
      nginx:
        stream_port: 6443           # 转发端口

    kube_vip:
      mode: arp

  addons:                           # --- 附加组件配置 ---
    metrics_server:
      enabled: true
      version: v0.7.0               # 一般不指定，走默认值

    dashboard:
      enabled: false
      version: v2.7.0               # 一般不指定，走默认值

    nodelocaldns:
      enabled: true

    storage:
      local_path_provisioner:
        enabled: false
        version: v0.0.26            # 一般不指定，走默认值

    ingress_controller:
      enabled: true
      type: nginx             # nginx | traefik
      version: v1.9.4
      host_network: true      # 是否使用主机网络

  nodes:
    kubelet:
      kube_reserved:
        cpu: "200m"
        memory: "256Mi"
      system_reserved:
        cpu: "200m"
        memory: "256Mi"
      eviction_hard:
        memory.available: "100Mi"
        nodefs.available: "10%"
    system:
      timezone: Asia/Shanghai
      ntp_servers:
        - ntp.aliyun.com
        - time.cloudflare.com

      disable_swap: true             # 禁用 swap
      disable_selinux: true          # 禁用 SELinux
      firewall:                      # 防火墙
        enabled: false

    sysctl:                          # 内核参数调优
      net.ipv4.ip_forward: 1
      net.bridge.bridge-nf-call-iptables: 1
      net.bridge.bridge-nf-call-ip6tables: 1
      vm.swappiness: 0

  certificates:
    validity_days: 3650              # 10年
    auto_renew:                      # 自动续期
      enabled: true
      days_before_expiry: 30

  backup:                            # --- 备份配置 ---
    etcd:                            # Etcd 备份
      enabled: true
      schedule: "0 2 * * *"         # 每天2点
      retention_days: 7
      backup_dir: /var/backups/etcd

  logging:                          # --- 日志配置 ---
    level: info                     # 日志级别: debug | info | warn | error
    log_dir: /var/log/kubexm         # 日志目录
    retention_days: 30                 # 日志保留天数

  advanced:                         # --- 高级配置 ---
    download:                       # 下载配置
      concurrency: 5                # 并发数
      retry: 3                      # 重试次数
      timeout: 300                  # 超时时间(秒)
    deploy:                         # 部署配置
      parallel_nodes: 3             # 并发节点数
      health_check_retries: 30      # 健康检查重试
    image_pull:                     # 镜像预拉取
      enabled: true
      parallel: 3

  registry:                         # --- Registry 配置 ---
    version: v2.8.3                 # 一般不指定，走默认值
    enable: false
    host: ""
    port: 5000
    auth:
      enabled: false
      username: "admin"
      password: "Harbor12345"
    data_dir: "/var/lib/registry"
    tls:
      enabled: false
      cert_file: "/etc/registry/tls/registry.crt"
      key_file: "/etc/registry/tls/registry.key"

  # --- 文件路径 ---
  paths:
    work_dir: "/tmp/kubexm"
    cache_dir: "/var/cache/kubexm"
```

注意：所有参数都要有默认值
```
kubexm create cluster 就能安装集群，这样一般是单节点集群，我不用配置host.yaml和config.yaml
kubexm create cluser --kubernetes-versoin=1.32也能安装集群，这样一般是单节点集群，我不用配置host.yaml和config.yaml
kubexm create cluser --kubernetes-versoin=1.32 --container-runtime=docker也能安装集群，这样一般是单节点集群，我不用配置host.yaml和config.yaml
kubexm create cluster --config config.yaml --host=host.yaml也能安装集群，这样一般是多节点集群
kubexm delete cluster
kubexm delete cluster --config config.yaml --host=host.yaml
```

## 1. 部署前置工作

### 1.1 部署模式选择
KubeXM 支持两种部署模式：
- **在线模式 (online)**: 直接从互联网下载所需资源
- **离线模式 (offline)**: 使用预先下载的资源包进行部署

### 1.2 离线模式准备工作
在离线模式下，必须完成以下准备工作：

#### 1.2.1 Registry 配置
- 必须启用 registry (`spec.registry.enable = true`)
- registry 组下必须配置机器列表
- registry 将在指定节点上部署私有镜像仓库

##### Registry Service 模板
模板放置在 `kubexm/templates/registry/registry.service.tmpl`，程序自动读取模板渲染出针对特定节点的配置放置在 `kubexm/packages/${node_name}/registry.service`

```ini
[Unit]
Description=Docker Registry
Documentation=https://docs.docker.com/registry/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/lib/registry
ExecStart=/usr/local/bin/registry serve /etc/registry/config.yml
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
```

##### Registry 配置模板
模板放置在 `kubexm/templates/registry/registry.config.tmpl`，程序自动读取模板渲染出针对特定节点的配置放置在 `kubexm/packages/${node_name}/config.yml`

```yaml
version: 0.1
log:
  level: info
  formatter: text
  fields:
    service: registry

storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true

http:
  addr: 0.0.0.0:5000
  headers:
    X-Content-Type-Options: [nosniff]
  debug:
    addr: 0.0.0.0:5001
    prometheus:
      enabled: true
      path: /metrics

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

#### 1.2.2 资源下载
执行以下下载操作将所需资源保存到本地：

##### 下载二进制文件
```
# 二进制文件将下载到以下路径
kubexm/packages/${component_name}/${component_version}/${arch}
```

##### 下载镜像
```
# 镜像将下载到以下路径
kubexm/packages/images/
# 根据配置确定是否下载多架构镜像
```

##### 下载系统依赖
```
# 系统依赖将使用Docker容器化构建系统下载并打包为 ISO 格式
kubexm/packages/system-packages.iso
# 或在离线构建模式下：
kubexm/packages/kubexm-system-packages.iso
```

**注意**: 系统包下载采用Docker容器化构建流程：
1. 使用Docker容器模拟不同操作系统环境
2. 自动解析并下载包依赖（repotrack/apt-rdepends）
3. 生成包含本地仓库的ISO文件
4. 支持多操作系统：CentOS, Rocky, AlmaLinux, Ubuntu, Debian, UOS, Kylin, openEuler
5. 支持多架构：amd64, arm64

**包含的系统包**：
系统包根据配置动态生成，包括：

**基础工具**：
- curl, wget, jq, vim, git, tar, gzip, unzip
- expect, sshpass, bash-completion

**网络相关**：
- conntrack-tools, ebtables, ethtool
- iproute2, iptables, ipvsadm, socat

**系统工具**：
- chrony (时间同步), rsync (文件同步), htop (系统监控)

**负载均衡器** (启用时)：
- haproxy, nginx, keepalived

**存储工具** (启用时)：
- nfs-utils/nfs-common, iscsi-initiator-utils/open-iscsi

**说明**：
- 包列表根据运行时类型、CN插件、负载均衡配置动态生成
- 支持所有13种操作系统
- 自动解析并下载所有依赖包

###### 目录结构
在构建机上，建立如下目录存放 Dockerfile：
```
kubexm/
├── dockerfiles/
│   ├── Dockerfile.centos7
│   ├── Dockerfile.centos8
│   ├── Dockerfile.centos9
│   ├── Dockerfile.rocky8
│   ├── Dockerfile.rocky9
│   ├── Dockerfile.alma8
│   ├── Dockerfile.alma9
│   ├── Dockerfile.ubuntu2004
│   ├── Dockerfile.ubuntu2204
│   ├── Dockerfile.ubuntu2404
│   ├── Dockerfile.debian12
│   ├── Dockerfile.uos20
│   └── Dockerfile.kylinv10
└── build.sh
```

###### 针对性编写 Dockerfile
- Dockerfile.centos7
  ```
  FROM centos:7
  RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
      sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
  RUN yum install -y epel-release && \
      yum install -y yum-utils createrepo
  WORKDIR /data
  ```

- Dockerfile.centos8
  ```
  FROM centos:8
  RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
      sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
  RUN yum install -y epel-release && \
      yum install -y dnf-utils createrepo_c
  WORKDIR /data
  ```

- Dockerfile.centos9
  ```
  FROM quay.io/centos/centos:stream9
  RUN dnf install -y epel-release && \
      dnf install -y dnf-utils createrepo_c && \
      dnf config-manager --set-enabled crb
  WORKDIR /data
  ```

- Dockerfile.rocky8
  ```
  FROM rockylinux:8
  RUN dnf install -y epel-release && \
      dnf install -y dnf-utils createrepo_c && \
      dnf config-manager --set-enabled powertools
  WORKDIR /data
  ```

- Dockerfile.rocky9
  ```
  FROM rockylinux:9
  RUN dnf install -y epel-release && \
      dnf install -y dnf-utils createrepo_c && \
      dnf config-manager --set-enabled crb
  WORKDIR /data
  ```

- Dockerfile.alma8
  ```
  FROM almalinux:8
  RUN dnf install -y epel-release && \
      dnf install -y dnf-utils createrepo_c && \
      dnf config-manager --set-enabled powertools
  WORKDIR /data
  ```

- Dockerfile.alma9
  ```
  FROM almalinux:9
  RUN dnf install -y epel-release && \
      dnf install -y dnf-utils createrepo_c && \
      dnf config-manager --set-enabled crb
  WORKDIR /data
  ```

- Dockerfile.kylinv10
  ```
  FROM kylin:v10-sp3
  RUN yum install -y yum-utils createrepo_c
  WORKDIR /data
  ```

- Dockerfile.ubuntu2004
  ```
  FROM ubuntu:20.04
  ENV DEBIAN_FRONTEND=noninteractive
  RUN apt-get update && \
      apt-get install -y dpkg-dev apt-rdepends wget
  WORKDIR /data
  ```

- Dockerfile.ubuntu2204
  ```
  FROM ubuntu:22.04
  ENV DEBIAN_FRONTEND=noninteractive
  RUN apt-get update && \
      apt-get install -y dpkg-dev apt-rdepends wget
  WORKDIR /data
  ```

- Dockerfile.ubuntu2404
  ```
  FROM ubuntu:24.04
  ENV DEBIAN_FRONTEND=noninteractive
  RUN apt-get update && \
      apt-get install -y dpkg-dev apt-rdepends wget
  WORKDIR /data
  ```

- Dockerfile.debian12
  ```
  FROM debian:12
  ENV DEBIAN_FRONTEND=noninteractive
  RUN apt-get update && \
      apt-get install -y dpkg-dev apt-rdepends wget
  WORKDIR /data
  ```

- Dockerfile.uos20
  ```
  FROM uos:20-server
  RUN yum install -y yum-utils createrepo_c
  WORKDIR /data
  ```


###### 构建脚本 (build.sh)
#!/bin/bash
BASE_DIR="$(pwd)/kubexm/packages/iso"

- [列表 A] 适用于 RHEL 系 (CentOS, Rocky, Alma, Kylin)
- 特征: 使用 nfs-utils, iscsi-initiator-utils, conntrack-tools
LIST_RHEL_KYLIN="socat conntrack-tools ipset ebtables ethtool ipvsadm expect fio curl wget chrony bash-completion rsync tar gzip unzip sshpass haproxy nginx keepalived nfs-utils iscsi-initiator-utils"

- [列表 B] 适用于 UOS 20 Server (RPM系，但包名特殊)
- 特征: 使用 nfs-common, open-iscsi, conntrack
LIST_UOS="socat conntrack ipset ebtables ethtool ipvsadm expect fio curl wget chrony bash-completion rsync tar gzip unzip sshpass haproxy nginx keepalived nfs-common open-iscsi"

- [列表 C] 适用于 Debian/Ubuntu
- 特征: 使用 nfs-common, open-iscsi, conntrack
  LIST_DEB="socat conntrack ipset ebtables ethtool ipvsadm expect fio curl wget chrony bash-completion rsync tar gzip unzip sshpass haproxy nginx keepalived nfs-common open-iscsi"

  ```
  
  ALL_TARGETS=(
      "centos 7 amd64"
      "centos 8 amd64"
      "centos 9 amd64"
      "rocky 8 amd64"
      "rocky 9 amd64"
      "alma 8 amd64"
      "alma 9 amd64"
      "kylin v10 amd64"
      "uos 20 amd64"
      "ubuntu 20.04 amd64"
      "ubuntu 22.04 amd64"
      "ubuntu 24.04 amd64"
      "debian 12 amd64"
  )
  
  
  run_build() {
      local OS_NAME=$1
      local OS_VER=$2
      local ARCH=$3
  
      local DOCKERFILE=""
      local PKG_MGR=""
      local PKG_LIST=""
      
      local VER_CLEAN=$(echo ${OS_VER} | tr -d '.')
  
      case "${OS_NAME}" in
          centos|rocky|alma)
              DOCKERFILE="dockerfiles/Dockerfile.${OS_NAME}${VER_CLEAN}"
              PKG_MGR="rpm"
              PKG_LIST="${LIST_RHEL_KYLIN}"
              ;;
          kylin)
              DOCKERFILE="dockerfiles/Dockerfile.${OS_NAME}${VER_CLEAN}"
              PKG_MGR="rpm"
              PKG_LIST="${LIST_RHEL_KYLIN}"
              ;;
          uos)
              DOCKERFILE="dockerfiles/Dockerfile.${OS_NAME}${VER_CLEAN}"
              PKG_MGR="rpm"
              PKG_LIST="${LIST_UOS}"
              ;;
          ubuntu|debian)
              DOCKERFILE="dockerfiles/Dockerfile.${OS_NAME}${VER_CLEAN}"
              PKG_MGR="deb"
              PKG_LIST="${LIST_DEB}"
              ;;
          *)
              echo "❌ 错误: 未知系统类型 ${OS_NAME}"
              return 1
              ;;
      esac
  
      if [ ! -f "${DOCKERFILE}" ]; then
          echo "❌ 错误: 找不到文件 ${DOCKERFILE}"
          return 1
      fi
  
      echo "--------------------------------------------------------"
      echo "🚀 开始任务: ${OS_NAME} ${OS_VER} [${ARCH}]"
      echo "   Dockerfile: ${DOCKERFILE}"
      echo "   包管理器:   ${PKG_MGR}"
      echo "--------------------------------------------------------"
  
      local TARGET_PATH="${BASE_DIR}/${OS_NAME}/${OS_VER}/${ARCH}"
      local ISO_FILE="${OS_NAME}_${OS_VER}_${ARCH}.iso"
      local TEMP_DIR="$(pwd)/temp_build_${OS_NAME}_${OS_VER}_${ARCH}"
      local IMAGE_TAG="builder-${OS_NAME}-${OS_VER}-${ARCH}"
  
      mkdir -p "${TARGET_PATH}"
      mkdir -p "${TEMP_DIR}"
  
      echo ">> [1/3] 构建环境镜像..."
      docker build --platform linux/${ARCH} -t ${IMAGE_TAG} -f ${DOCKERFILE} .
      if [ $? -ne 0 ]; then
          echo "❌ 镜像构建失败"
          rm -rf ${TEMP_DIR}
          return 1
      fi
  
      echo ">> [2/3] 智能解析依赖并下载..."
      
      local CMD=""
      if [ "$PKG_MGR" == "rpm" ]; then
          CMD="repotrack -a ${ARCH} -p /data ${PKG_LIST} && (createrepo_c /data || createrepo /data)"
      else
          CMD="cd /data && apt-get update && \
               echo '正在通过 APT 求解器计算最佳依赖路径...' && \
               \
               apt-get install -y --no-install-recommends --reinstall --print-uris ${PKG_LIST} > deps_info.txt && \
               \
               echo '提取下载链接...' && \
               grep -o \"http.*\.deb\" deps_info.txt | sed \"s/'//g\" > urls.txt && \
               \
               COUNT=\$(wc -l < urls.txt) && \
               echo \"解析完成，共需下载 \$COUNT 个无冲突的包。\" && \
               \
               wget -q --show-progress -i urls.txt && \
               \
               echo '正在生成索引...' && \
               dpkg-scanpackages . /dev/null > Packages && gzip -k -f Packages"
      fi
  
      docker run --rm --platform linux/${ARCH} -v ${TEMP_DIR}:/data ${IMAGE_TAG} /bin/bash -c "${CMD}"
      
      if [ $? -ne 0 ]; then 
          echo "❌ 下载过程报错"
          rm -rf ${TEMP_DIR}
          docker rmi ${IMAGE_TAG} >/dev/null 2>&1
          return 1
      fi
  
      if [ -z "$(ls -A ${TEMP_DIR})" ]; then
         echo "❌ 错误：下载目录为空，未下载到任何包。"
         rm -rf ${TEMP_DIR}
         docker rmi ${IMAGE_TAG} >/dev/null 2>&1
         return 1
      fi
  
      echo ">> [3/3] 打包 ISO..."
      mkisofs -J -R -V "KUBEXM_REPO" -o "${TARGET_PATH}/${ISO_FILE}" ${TEMP_DIR} >/dev/null 2>&1
      
      if [ $? -eq 0 ]; then
          echo "✅ 成功: ${TARGET_PATH}/${ISO_FILE}"
      else
          echo "❌ ISO 生成失败"
      fi
  
      rm -rf ${TEMP_DIR}
      docker rmi ${IMAGE_TAG} >/dev/null 2>&1
  }
  
  
  if [ "$1" == "all" ]; then
      echo ">>> 启动全量构建模式 (共 ${#ALL_TARGETS[@]} 个目标)..."
      for target in "${ALL_TARGETS[@]}"; do
          # 将 "centos 7 amd64" 拆分为参数 $1 $2 $3 传递给函数
          run_build $target
      done
      echo ">>> 所有任务执行完毕。"
  elif [ $# -eq 3 ]; then
      # 单个构建模式: ./build.sh os version arch
      run_build $1 $2 $3
  else
      echo "参数错误。"
      echo "用法:"
      echo "  1. 构建所有预定义目标: $0 all"
      echo "  2. 构建单个目标:       $0 <os_name> <os_version> <arch>"
      echo ""
      echo "示例:"
      echo "  $0 centos 7 amd64"
      echo "  $0 uos 20 amd64"
      echo "  $0 ubuntu 22.04 amd64"
      exit 1
  fi
  ```

###### 将iso文件分发到目标机器
```
scp kubexm/packages/iso/${os_name}/${os_version}/${arch}/${os_name}_${os_version}_${arch}.iso user@ip:/tmp/${os_name}_${os_version}_${arch}.iso
```

###### 离线安装脚本
这个脚本直接在目标机器上运行
```
#!/bin/bash

# 1. 识别操作系统和架构
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
    MAJOR_VERSION=$(echo $OS_VERSION | cut -d. -f1)
else
    echo "无法识别操作系统"
    exit 1
fi

ARCH=$(uname -m)
[ "$ARCH" == "x86_64" ] && ARCH="amd64"
[ "$ARCH" == "aarch64" ] && ARCH="arm64"

ISO_NAME="${OS_NAME}_${OS_VERSION}_${ARCH}.iso"
SRC_ISO="/tmp/${ISO_NAME}"
MOUNT_POINT="/tmp/kubexmiso"
echo "目标系统: ${OS_NAME} ${OS_VERSION} ${ARCH}"
echo "寻找镜像: ${SRC_ISO}"
if [ ! -f "${SRC_ISO}" ]; then
    echo "错误：找不到文件 ${SRC_ISO}"
    echo "请确保 ISO 已复制到 /tmp/ 目录，且命名格式正确。"
    exit 1
fi
mkdir -p ${MOUNT_POINT}
umount ${MOUNT_POINT} 2>/dev/null
echo "挂载 ISO..."
mount -o loop "${SRC_ISO}" ${MOUNT_POINT}
if [ $? -ne 0 ]; then
    echo "挂载失败"
    exit 1
fi
BACKUP_DIR="/etc/repo_backup_$(date +%Y%m%d%H%M)"
mkdir -p ${BACKUP_DIR}

setup_rpm_repo() {
    echo "备份 Yum/Dnf 源..."
    mv /etc/yum.repos.d/*.repo ${BACKUP_DIR}/ 2>/dev/null
    echo "写入新源..."
    cat > /etc/yum.repos.d/kubexm-iso.repo <<EOF
[kubexm-iso]
name=Kubexm Offline ISO
baseurl=file://${MOUNT_POINT}
gpgcheck=0
enabled=1
EOF
    if command -v dnf >/dev/null; then
        dnf clean all && dnf makecache
        dnf install -y socat conntrack-tools ipset ebtables ethtool ipvsadm expect fio curl wget chrony bash-completion rsync tar gzip unzip sshpass haproxy nginx keepalived nfs-utils iscsi-initiator-utils
    else
        yum clean all && yum makecache
        yum install -y socat conntrack-tools ipset ebtables ethtool ipvsadm expect fio curl wget chrony bash-completion rsync tar gzip unzip sshpass haproxy nginx keepalived nfs-utils iscsi-initiator-utils
    fi
}
setup_deb_repo() {
    echo "备份 Apt 源..."
    mv /etc/apt/sources.list ${BACKUP_DIR}/ 2>/dev/null
    mv /etc/apt/sources.list.d/*.list ${BACKUP_DIR}/ 2>/dev/null
    
    echo "写入新源..."
    echo "deb [trusted=yes] file:${MOUNT_POINT} ./" > /etc/apt/sources.list
    
    apt-get update
    # --allow-unauthenticated 确保离线包无签名也能装
    apt-get install -y --allow-unauthenticated socat conntrack ipset ebtables ethtool ipvsadm expect fio curl wget chrony bash-completion rsync tar gzip unzip sshpass haproxy nginx keepalived nfs-common open-iscsi
}

case "${OS_NAME}" in
    centos|rhel|rocky|almalinux|kylin|uos)
        setup_rpm_repo
        ;;
    ubuntu|debian)
        setup_deb_repo
        ;;
    *)
        echo "不支持的系统类型: ${OS_NAME}"
        exit 1
        ;;
esac
echo "安装完成。"
```

###### 安装完成后执行清理动作
- 卸载 ISO：umount /mnt/kubexmiso
- 删除临时 ISO 文件：rm -f /tmp/xxx.iso /tmp/kubexmiso
- 恢复之前的 .repo 或 sources.list 备份文件
- **注意**: haproxy、nginx、keepalived要根据条件离线和安装，默认不离线和安装
  - 如果loadbalancer启用mode为external且type为kubexm-kh, 则在loadbalancer组的机器上安装keepalived、haproxy
  - 如果loadbalancer启用mode为external且type为kubexm-kn, 则在loadbalancer组的机器上安装keepalived、nginx
  - 如果loadbalancer启用mode为internal且kubernetes.type为kubexm，loadBalancer.type为haproxy,则在所有worker上部署haproxy
  - 如果loadbalancer启用mode为internal且kubernetes.type为kubexm，loadBalancer.type为nginx,则在所有worker上部署nginx

- **系统包安装说明**: 系统包通过ISO中的本地仓库安装，包含所有必要依赖：
  - ISO挂载后会自动配置本地yum/apt仓库
  - 根据操作系统类型自动选择RPM或DEB包安装
  - 支持多架构自动适配（amd64/arm64）

### 1.3 环境检查与准备

#### 1.3.1 检查主机连通性
```
ping -c 4 <host_ip>
```

#### 1.3.2 检查必要组件是否安装
```
command -v socat
conntrack --version
command -v conntrack
ctr --version
```

#### 1.3.3 安装系统依赖
根据不同操作系统安装必要的依赖包：
- centos7、centos8、centos9、rocky8、rocky9、alma8、alma9
```
yum install socat、conntrack-tools、ipset、ebtables、ethtool、ipvsadm、expect、fio、curl、wget、chrony、bash-completion、rsync、tar、gzip、unzip、sshpass、haproxy、nginx、keepalived、nfs-utils、iscsi-initiator-utils
```
- Ubunt20.04、Ubunt22.04、Ubunt24.04、debian12
```
apt install socat、conntrack、ipset、ebtables、ethtool、ipvsadm、expect、fio、curl、wget、chrony、bash-completion、rsync、tar、gzip、unzip、sshpass、haproxy、nginx、keepalived、nfs-common、open-iscsi
```
- uos20server(是rpm系的)
```
yum install socat、conntrack、ipset、ebtables、ethtool、ipvsadm、expect、fio、curl、wget、chrony、bash-completion、rsync、tar、gzip、unzip、sshpass、haproxy、nginx、keepalived、nfs-common、open-iscsi
```
- kylin-v10-sp3(是rpm系的)
```
yum install socat、conntrack-tools、ipset、ebtables、ethtool、ipvsadm、expect、fio、curl、wget、chrony、bash-completion、rsync、tar、gzip、unzip、sshpass、haproxy、nginx、keepalived、nfs-utils、iscsi-initiator-utils
```

- **注意**: haproxy、nginx、keepalived要根据条件离线和安装，默认不离线和安装
  - 如果loadbalancer启用mode为external且type为kubexm-kh, 则在loadbalancer组的机器上安装keepalived、haproxy
  - 如果loadbalancer启用mode为external且type为kubexm-kn, 则在loadbalancer组的机器上安装keepalived、nginx
  - 如果loadbalancer启用mode为internal且kubernetes.type为kubexm，loadBalancer.type为haproxy,则在所有worker上部署haproxy
  - 如果loadbalancer启用mode为internal且kubernetes.type为kubexm，loadBalancer.type为nginx,则在所有worker上部署nginx

- **系统包安装说明**: 系统包通过ISO中的本地仓库安装，包含所有必要依赖：
  - ISO挂载后会自动配置本地yum/apt仓库
  - 根据操作系统类型自动选择RPM或DEB包安装
  - 支持多架构自动适配（amd64/arm64）

#### 1.3.4 系统配置优化
##### 禁用 swap
```
swapoff -a
sed -i /^[^#]*swap*/s/^/\#/g /etc/fstab
```
- **动作**：
  - swapoff -a：立即关闭当前系统运行中的所有 Swap 分区。
  - sed ... /etc/fstab：修改文件系统挂载表，注释掉包含 "swap" 的行，防止服务器重启后 Swap 自动重新挂载。
- **目的**：**Kubernetes 的强制要求**。Kubelet（K8s 的节点代理）默认情况下如果在检测到 Swap 开启会拒绝启动。因为 Swap 会导致内存计算不准确，影响调度器的决策和 Pod 的性能稳定性。

##### 禁用 SELinux
```
if [ -f /etc/selinux/config ]; then
  sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
fi
if command -v setenforce &> /dev/null
then
  setenforce 0
  getenforce
fi
```
- **动作**：
  - 修改配置文件将 SELinux 状态改为 disabled（永久生效）。
  - 使用 setenforce 0 将当前运行状态改为宽容模式（Permissive，即时生效）。
- **目的**：**消除权限障碍**。SELinux 的强制访问控制策略经常会拦截容器（Docker/Containerd）挂载主机目录或进行复杂的网络操作。为了避免莫名其妙的 "Permission denied" 错误，安装 K8s 时通常建议关闭它。


##### 关闭系统防火墙
```
systemctl stop firewalld ...
systemctl disable firewalld ...
systemctl stop ufw ...
systemctl disable ufw ...
```
- **动作**：停止并禁用 CentOS 的 firewalld 和 Ubuntu 的 ufw 服务。
- **目的**：**防止网络规则冲突**。Kubernetes 拥有自己的网络管理机制（通过 iptables 或 IPVS 动态生成规则）。宿主机的防火墙规则容易屏蔽 Pod 流量或服务端口，导致集群网络不通。

##### 加载基础内核模块 (Overlay & Bridge)
```
modinfo br_netfilter ...
modprobe br_netfilter
...
modinfo overlay ...
modprobe overlay
```
- **动作**：检测并加载 br_netfilter 和 overlay 模块，并写入配置文件确保重启自动加载。
- **目的**：
  - br_netfilter：配合第 3 块中的内核参数，让 Linux 网桥能够处理网络流量过滤，CNI 插件必备。
  - overlay：这是目前容器运行时（Docker/Containerd）主流使用的联合文件系统（UnionFS）驱动，用于管理容器的分层存储。

##### 加载 IPVS 模块 (高性能网络)

```
  modprobe ip_vs
  modprobe ip_vs_rr
  ...
  cat > /etc/modules-load.d/kube_proxy-ipvs.conf << EOF
  ...
  EOF
  modprobe nf_conntrack ...
  sysctl -p
```
- **动作**：加载 ip_vs（IP Virtual Server）及其相关的负载均衡算法模块（轮询 rr、加权轮询 wrr 等），以及连接追踪模块 nf_conntrack。最后执行 sysctl -p 应用第 3 块的参数。
- **目的**：**启用 kube-proxy 的 IPVS 模式**。
  - 相比默认的 iptables 模式，IPVS 基于哈希表实现，在成千上万个 Service 的大规模集群中，IPVS 的网络转发性能极其优秀（O(1) 复杂度 vs iptables 的 O(n) 复杂度）。

##### 优化内核参数 (Sysctl)
将配置写入 /etc/sysctl.d/99-kubexm.conf 是 Linux 系统管理的最佳实践

```
    # --- 1. 网络基础与转发 ---
    net.ipv4.ip_forward = 1
    net.bridge.bridge-nf-call-arptables = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    
    # --- 2. 核心：ARP (邻居表) 扩容 ---
    # 600节点必须大幅调大，否则跨节点通信会随机断连
    net.ipv4.neigh.default.gc_thresh1 = 4096
    net.ipv4.neigh.default.gc_thresh2 = 8192
    net.ipv4.neigh.default.gc_thresh3 = 65536
    net.ipv4.neigh.default.gc_interval = 5
    net.ipv4.neigh.default.gc_stale_time = 120
    
    # --- 3. 核心：Conntrack (连接追踪) 扩容 ---
    # 建议配合 RAM 大小调整，这里按 64G+ 内存的标准配置
    # 注意：需要加载 nf_conntrack 模块
    net.netfilter.nf_conntrack_max = 2097152
    net.netfilter.nf_conntrack_tcp_timeout_established = 86400
    net.netfilter.nf_conntrack_tcp_timeout_close_wait = 3600
    
    # --- 4. 文件系统与句柄 ---
    # 大规模日志采集必备
    fs.inotify.max_user_instances = 8192
    fs.inotify.max_user_watches = 1048576
    fs.file-max = 10000000
    fs.nr_open = 10000000
    
    # --- 5. 进程与内存 ---
    kernel.pid_max = 4194303
    vm.max_map_count = 524288
    vm.swappiness = 1
    # 发生 OOM 时快速恢复
    vm.panic_on_oom = 0
    vm.overcommit_memory = 1
    
    # --- 6. 高并发网络优化 ---
    # 增加 Socket 监听队列，防止突发流量导致连接拒绝
    net.core.somaxconn = 32768
    net.core.netdev_max_backlog = 32768
    net.ipv4.tcp_max_syn_backlog = 16384
    net.ipv4.ip_local_port_range = 1024 65000
    
    # --- 7. K8s Service ---
    net.ipv4.ip_local_reserved_ports = 30000-32767
    
    # -- Legacy Support (Only for Kernel < 4.12) --
    # 如果你的内核 > 4.12，下面这行会自动报错忽略，或者建议直接删掉
    net.ipv4.tcp_tw_recycle = 0
```

- **动作**：向 /etc/sysctl.conf 写入配置，并使用 sed 修正已存在的配置，最后用 awk 去除重复行。
- **关键参数解读**：
  - net.ipv4.ip_forward = 1：开启 IP 转发，Pod 之间跨节点通信的根本基础。
  - net.bridge.bridge-nf-call-iptables = 1：确保经过网桥的流量被 iptables 处理，这是 K8s 网络插件（CNI）工作的核心。
  - net.ipv4.ip_local_reserved_ports = 30000-32767：**预留端口**，这是 K8s NodePort 服务的默认范围，防止被其他随机进程占用。
  - vm.max_map_count = 262144：**Elasticsearch 专用**。KubeSphere 的日志组件通常包含 ES，ES 启动时要求此值至少为 262144，否则会启动失败。
  - vm.swappiness = 1：最大限度减少系统使用 Swap 的倾向（即使 Swap 没关干净）。
  - fs.inotify.max_user_instances：增加文件监控句柄上限，防止 kubectl logs -f 或日志收集器报错。
  - 关于 net.ipv4.tcp_tw_recycle：
    这个参数在较新的 Linux 内核（4.12+）中已经被移除了。
    如果你的系统是 CentOS 7 (内核 3.10)，这个参数没问题。
    如果你的系统是 Ubuntu 20.04+ 或 CentOS Stream 9 (内核 5.x+)，写入这个参数可能会在执行 sysctl --system 时报错 cannot stat /proc/sys/net/ipv4/tcp_tw_recycle。
  ```
    if [ -f /proc/sys/net/ipv4/tcp_tw_recycle ]; then
        echo "net.ipv4.tcp_tw_recycle = 0" >> $SYSCTL_CONF
    fi
  ```
##### 兼容性调整与资源限制
```
echo 3 > /proc/sys/vm/drop_caches
update-alternatives --set iptables /usr/sbin/iptables-legacy ...
ulimit -u 65535
ulimit -n 65535
```
- **动作**：
  1. drop_caches：强制释放页缓存、目录项缓存和 inode 缓存，释放内存空间。
  2. update-alternatives ... iptables-legacy：强制将系统 iptables 工具切换到 **Legacy（旧版）模式**，而不是较新的 nftables 模式。这是因为 K8s 和由于 CNI 插件对 nftables 的支持仍不完善。
  3. ulimit：将最大进程数 (-u) 和最大文件打开数 (-n) 临时设置为 65535。
- **目的**：**确保环境稳定**。防止因为文件句柄耗尽导致程序崩溃，以及防止 iptables 版本不兼容导致的网络规则失效。


##### 配置集群 Hosts 解析
```
sed -i ':a;$!{N;ba};s@# kubexm hosts BEGIN.*# kubexm hosts END@@' /etc/hosts
...
cat >>/etc/hosts<<EOF
# kubexm hosts BEGIN
172.30.1.12  node2.cluster.local node2
...
172.30.1.12  lb.cars.local
# kubexm hosts END
EOF
```
- **动作**：先清理旧的 Kubexm 标记块，然后写入新的 IP 与主机名映射。
- **目的**：**节点互信与内部通信**。
  - 确保集群内所有节点（Node1-Node9）可以通过主机名相互 Ping 通。
  - lb.cars.local 通常用于指向集群的负载均衡器地址（API Server 的高可用入口,根据配置文件确定。
  - registry.kubexm.local 可能是配置了私有镜像仓库地址,根据配置文件确定。
  
## 运行时
### 2.1 场景说明
根据运行时类型，本系统支持containerd、cri-o、docker三种类型
### 2.2 运行时是containerd
#### 2.2.1下载并放在kubexm/packages/containerd/v${containerd_version}/${arch}/
```
https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}-linux-${arch}.tar.gz
```
#### 2.2.2 将其复制到目标机器、解压、安装到/usr/local/bin
#### 2.2.3 设置内核参数
```
# 加载必要模块
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 设置内核参数
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
```
#### 2.2.4 配置 systemd 服务
- 此模板放置在kubexm/templates/containerd/containerd.service.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/containerd/containerd.service
```
cat <<EOF > /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# LimitNOFILE=1048576
# LimitNPROC=infinity
# LimitCORE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF
```
#### 2.2.5 配置containerd
- 此模板放置在kubexm/templates/containerd/config.toml.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/containerd/config.toml
```
version = 2

root = "/var/lib/containerd"
state = "/run/containerd"
oom_score = 0

[grpc]
  address = "/run/containerd/containerd.sock"
  uid = 0
  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[debug]
  address = ""
  uid = 0
  gid = 0
  level = ""

[metrics]
  address = ""
  grpc_histogram = false

[cgroup]
  path = ""

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "${PAUSE_IMAGE}"
    max_container_log_line_size = 16384
    
    [plugins."io.containerd.grpc.v1.cri".cni]
      bin_dir = "/opt/cni/bin"
      conf_dir = "/etc/cni/net.d"
      max_conf_num = 1
      conf_template = ""
    
    [plugins."io.containerd.grpc.v1.cri".containerd]
      snapshotter = "overlayfs"
      default_runtime_name = "runc"
      no_pivot = false
      disable_snapshot_annotations = true
      discard_unpacked_layers = false
      
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          runtime_engine = ""
          runtime_root = ""
          privileged_without_host_devices = false
          base_runtime_spec = ""
          
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
    
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
      
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://registry-1.docker.io"]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
          endpoint = ["https://registry.k8s.io"]

```
#### 2.2.6 runc
##### 2.2.6.1 下载并放在kubexm/packages/runc/v${runc_version}/${arch}/
```
https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.${arch}
```
#### 2.2.7 cni-plugins
##### 2.2.7.1 下载并放在kubexm/packages/cni-plugins/v${cni_plugins_version}/${arch}/
```
https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_version}/cni-plugins-linux-${arch}-v${cni_plugins_version}.tgz
```
#### 2.2.8 crictl
##### 2.2.8.1 下载并放在kubexm/packages/crictl/v${crictl_version}/${arch}/
```
https://github.com/kubernetes-sigs/cri-tools/releases/download/v${crictl_version}/crictl-v${crictl_version}-linux-${arch}.tar.gz
```
##### 2.2.9 crictl配置
```
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```
### 2.2 运行时是docker
#### 加载必要的内核参数，在目标机器执行
```
# 1. 加载必要内核模块
modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 2. 设置内核参数 (开启 IP 转发和桥接流量监控)
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
```
#### 下载并放在kubexm/packages/docker/${docker_version}/${arch}/
```
https://download.docker.com/linux/static/stable/${arch}/docker-${version}.tgz # 注意这里的arch是x86_64,注意处理x86_64和amd64的转换
```
#### docker的service
- 此模板放置在kubexm/templates/docker/docker.service.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/docker/docker.service
```
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
```

#### 配置docker
- 此模板放置在kubexm/templates/docker/daemon.json.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/docker/daemon.json
```
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "10"
  },
  "storage-driver": "overlay2",
  "registry-mirrors": [
    "https://registry.docker-cn.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "insecure-registries": [],
  "live-restore": true,
  "userland-proxy": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    },
    "nproc": {
      "Name": "nproc",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}

```

#### cri-dockerd
##### 下载并放在kubexm/packages/cri-dockerd/v${cri_dockerd_version}/${arch}/
```
https://github.com/Mirantis/cri-dockerd/releases/download/v${cri_dockerd_version}/cri-dockerd-${cri_dockerd_version}.${arch}.tgz
```
##### cri-dockerd.service
- 此模板放置在kubexm/templates/cri-dockerd/cri-dockerd.service.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/cri-dockerd/cri-dockerd.service
- 注意registry.k8s.io/pause:3.9，离线模式要动态确定
```
Description=CRI Interface for Docker Application Container Engine
Documentation=https://docs.mirantis.com
After=network-online.target firewalld.service docker.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cri-dockerd --containerd-namespace k8s.io --pod-infra-container-image registry.k8s.io/pause:3.9
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### crictl
##### 下载并放在kubexm/packages/crictl/v${crictl_version}/${arch}/
```
https://github.com/kubernetes-sigs/cri-tools/releases/download/v${crictl_version}/crictl-v${crictl_version}-linux-${arch}.tar.gz
```
##### crictl配置
```
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/cri-dockerd.sock
image-endpoint: unix:///run/cri-dockerd.sock
timeout: 10
debug: false
EOF
```
#### kubelet
```
runtimeEndpoint: unix:///run/cri-dockerd.sock
```

### 2.3 运行时是cri-o
#### 加载必要的内核参数，在目标机器执行
```
# 1. 加载模块
modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

# 2. 内核参数 (开启转发)
cat <<EOF > /etc/sysctl.d/99-kubernetes-crio.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system
```
#### 下载并放在kubexm/packages/cri-o/v${crio_version}/${arch}/
```
https://storage.googleapis.com/cri-o/artifacts/cri-o.${arch}.v{crio_version}.tar.gz
```

#### 配置cri-o.service
- 此模板放置在kubexm/templates/cri-o/cri-o.service.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/cri-o/cri-o.service
```
[Unit]
Description=CRI-O - OCI-based implementation of Kubernetes Container Runtime Interface
Documentation=https://github.com/cri-o/cri-o
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/crio
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
```

#### 确保目录存在
```
mkdir -p /etc/crio
mkdir -p /var/lib/crio
mkdir -p /var/log/crio
```

#### 配置镜像策略 (policy.json)
```
mkdir -p /etc/containers
cat <<EOF > /etc/containers/policy.json
{
    "default": [
        {
            "type": "insecureAcceptAnything"
        }
    ],
    "transports": {
        "docker-daemon": {
            "": [{"type": "insecureAcceptAnything"}]
        }
    }
}
EOF
```

#### 配置 crio.conf
```
# CRI-O 核心配置文件
# 路径: /etc/crio/crio.conf

[crio]
  # 根目录，存储容器数据
  root = "/var/lib/containers/storage"
  # 运行状态目录
  runroot = "/var/run/containers/storage"
  # 存储驱动 (通常是 overlay)
  storage_driver = "overlay"
  # 存储选项
  storage_option = [
    "overlay.mountopt=nodev,metacopy=on"
  ]

[crio.api]
  # CRI-O 监听的 Socket 路径 (Kubelet 需连接此地址)
  listen = "/var/run/crio/crio.sock"
  # 流式服务地址 (exec/logs)
  stream_address = "127.0.0.1"
  stream_port = "0"
  stream_enable_tls = false
  stream_idle_timeout = "30s"

[crio.runtime]
  # 【关键】Cgroup 管理器，K8s 强制要求 systemd
  cgroup_manager = "systemd"
  
  # 默认 OCI 运行时名称
  default_runtime = "runc"
  
  # 钩子目录
  hooks_dir = [
    "/usr/share/containers/oci/hooks.d",
    "/etc/containers/oci/hooks.d"
  ]
  
  # 容器监控进程 conmon 的路径 (二进制部署必须确认此路径存在)
  conmon = "/usr/local/bin/conmon"
  conmon_cgroup = "system.slice"
  conmon_env = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  ]

  # 默认容器 ulimit 设置
  default_ulimits = [
    "nofile=1048576:1048576"
  ]

  # 定义具体的运行时 (runc)
  [crio.runtime.runtimes.runc]
    # runc 二进制文件路径 (二进制部署必须确认此路径存在)
    runtime_path = "/usr/local/sbin/runc"
    runtime_type = "oci"
    runtime_root = "/run/runc"
    # 允许特权容器
    privileged_without_host_devices = false

[crio.image]
  # 【必须修改】Pause 镜像地址 (如果是离线环境，请改为私有仓库地址)
  # 例如: "192.168.1.100/library/pause:3.9"
  pause_image = "registry.k8s.io/pause:3.9"
  
  # 镜像拉取相关配置
  pause_image_auth_file = "/var/lib/kubelet/config.json"
  pause_command = "/pause"
  
  # 是否允许系统级的镜像签名策略 (离线私有仓库通常需要设为 false 或正确配置 policy.json)
  signature_policy = "/etc/containers/policy.json"
  
  # 镜像拉取超时时间
  pull_progress_timeout = "1m"

  # 【可选】私有仓库配置 (如果不配置 system wide registries.conf)
  # insecure_registries = [
  #   "192.168.1.100"
  # ]
  # registries = [
  #   "docker.io"
  # ]

[crio.network]
  # CNI 网络插件配置目录
  network_dir = "/etc/cni/net.d/"
  # CNI 插件二进制文件目录 (必须确认路径正确)
  plugin_dirs = [
    "/opt/cni/bin/",
    "/usr/libexec/cni/"
  ]

[crio.metrics]
  # 是否开启 Prometheus 指标
  enable_metrics = true
  metrics_port = 9090
```

#### conmon
##### 下载并放在kubexm/packages/conmon/v${conmon_version}/${arch}/
```
https://github.com/containers/conmon/releases/download/v${conmon_version}/conmon.${arch}
```

#### runc
##### 下载并放在kubexm/packages/runc/v${runc_version}/${arch}/
```
https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.${arch}
```
#### cni-plugins
##### 下载并放在kubexm/packages/cni-plugins/v${cni_plugins_version}/${arch}/
```
https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_version}/cni-plugins-linux-${arch}-v${cni_plugins_version}.tgz
```
#### crictl
##### 下载并放在kubexm/packages/crictl/v${crictl_version}/${arch}/
```
https://github.com/kubernetes-sigs/cri-tools/releases/download/v${crictl_version}/crictl-v${crictl_version}-linux-${arch}.tar.gz
```
##### crictl配置
```
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///var/run/crio/crio.sock
image-endpoint: unix:///var/run/crio/crio.sock
timeout: 10
debug: false
pull-image-on-create: false
disable-pull-on-run: false
EOF
```

#### kubelet
```
--container-runtime-endpoint=unix:///var/run/crio/crio.sock
```

## etcd部署
### 如果etcd是kubeadm部署，则跳过此步
### 如果etcd是kubexm部署
- 我们将生成以下文件，结构完全对标 Kubeadm：
  - Etcd CA: ca.crt, ca.key (信任根)
  - Server 证书: server.crt, server.key (仅用于 2379 端口，ServerAuth)
  - Peer 证书: peer.crt, peer.key (仅用于 2380 端口，ServerAuth + ClientAuth)
  - Healthcheck 客户端: healthcheck-client.crt, healthcheck-client.key (仅用于本地 etcdctl，ClientAuth)
  - APIServer 客户端: apiserver-etcd-client.crt, apiserver-etcd-client.key (给 K8s APIServer 用的，ClientAuth)
- 所有证书放在kubexm/packages/${node_name}/certs下，就算各个节点证书一样，你也得在每个etcd节点的这个目录放置一份
#### 生成CA
```
# 生成 CA 私钥
openssl genrsa -out ca.key 2048

# 生成 CA 证书
openssl req -x509 -new -nodes -key ca.key \
  -subj "/CN=etcd-ca" \
  -days 36500 \
  -out ca.crt
```

#### 生成 Server 证书 (监听 2379)
这是 Etcd 对外提供服务时验证自己身份用的。
##### 配置文件 (openssl-server.cnf):
```
# =========================================================
# 2. 生成 OpenSSL 配置文件
# =========================================================
cat > openssl-server.cnf <<EOF
[ req ]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
# --- 域名部分 (DNS) ---
DNS.1 = localhost
DNS.2 = ${NODE1_NAME}
DNS.3 = ${NODE2_NAME}
DNS.4 = ${NODE3_NAME}

# --- IP 地址部分 (IP) ---
IP.1 = 127.0.0.1
IP.2 = ${NODE1_IP}
IP.3 = ${NODE2_IP}
IP.4 = ${NODE3_IP}
EOF

# =========================================================
# 3. 生成 Server 证书
# =========================================================

# 生成私钥
openssl genrsa -out server.key 2048

# 生成 CSR (证书签名请求)
# 注意：CN 这里我写了 etcd-server，实际上因为有了 SAN，CN 不再那么重要，
# 但为了规范，你可以填第一个节点的名字，或者保持泛称。
openssl req -new -key server.key \
  -subj "/CN=etcd-server" \
  -config openssl-server.cnf \
  -out server.csr

# 使用 CA 签发证书
openssl x509 -req -in server.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out server.crt \
  -days 36500 \
  -extensions v3_req \
  -extfile openssl-server.cnf
```

#### 生成 Peer 证书 (监听 2380)
这是 Etcd 节点之间数据同步用的。
##### 配置文件 (openssl-peer.cnf):
- 必须包含 serverAuth 和 clientAuth (节点互连既是客也是主)。
- SAN 必须包含：所有节点 IP (通常不需要 127.0.0.1)。
```
# =========================================================
# 2. 生成 Peer 配置文件 (openssl-peer.cnf)
# =========================================================
# 关键点：
# 1. extendedKeyUsage 必须同时包含 serverAuth 和 clientAuth
# 2. SAN 包含：Hostnames, localhost, 真实IP, 127.0.0.1
cat > openssl-peer.cnf <<EOF
[ req ]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[ alt_names ]
# --- 域名部分 ---
DNS.1 = localhost
DNS.2 = ${NODE1_NAME}
DNS.3 = ${NODE2_NAME}
DNS.4 = ${NODE3_NAME}

# --- IP 地址部分 ---
IP.1 = 127.0.0.1
IP.2 = ${NODE1_IP}
IP.3 = ${NODE2_IP}
IP.4 = ${NODE3_IP}
EOF

# =========================================================
# 3. 生成 Peer 私钥和证书
# =========================================================

# 生成 Peer 私钥
openssl genrsa -out peer.key 2048

# 生成 CSR
# CN 设为 etcd-peer
openssl req -new -key peer.key \
  -subj "/CN=etcd-peer" \
  -config openssl-peer.cnf \
  -out peer.csr

# 签发证书
openssl x509 -req -in peer.csr \
  -CA ca.crt \
  -CAkey ca.key \
  -CAcreateserial \
  -out peer.crt \
  -days 36500 \
  -extensions v3_req \
  -extfile openssl-peer.cnf
```
#### 生成 Healthcheck Client 证书
这是给本地 etcdctl 或 K8s 存活探针用的。
##### 配置文件:
- 只需要 clientAuth。
- 不需要 IP SAN，只需要 CN 标识身份。
```
# 这里直接用命令行参数指定 extension，不需额外配置文件
openssl genrsa -out healthcheck-client.key 2048
openssl req -new -key healthcheck-client.key -subj "/CN=kube-etcd-healthcheck-client/O=system:masters" -out healthcheck-client.csr

# 签发时指定 clientAuth
cat > openssl-client.cnf <<EOF
[ client_auth ]
extendedKeyUsage = clientAuth
EOF

openssl x509 -req -in healthcheck-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out healthcheck-client.crt -days 36500 -extensions client_auth -extfile openssl-client.cnf
```

#### 生成 APIServer Client 证书
这是给 Kube-Apiserver 连接 Etcd 用的。
##### 特点:
- 只需要 clientAuth。
- CN 通常设为 kube-apiserver-etcd-client。
- Org 设为 system:masters。
```
openssl genrsa -out apiserver-etcd-client.key 2048
openssl req -new -key apiserver-etcd-client.key -subj "/CN=kube-apiserver-etcd-client/O=system:masters" -out apiserver-etcd-client.csr

# 复用上面的 openssl-client.cnf
openssl x509 -req -in apiserver-etcd-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver-etcd-client.crt -days 36500 -extensions client_auth -extfile openssl-client.cnf
```

#### 分发与配置指南
现在你手里的文件结构和 Kubeadm 生成的逻辑是一致的。
##### 分发文件
将以下文件分发到所有 Etcd 节点的 /etc/kubernetes/pki/etcd：
- ca.crt
- server.crt, server.key
- peer.crt, peer.key
- healthcheck-client.crt, healthcheck-client.key
将以下文件分发到所有 K8s Master 节点的 /etc/kubernetes/pki/ (用于配置 APIServer)：
- ca.crt (重命名为 etcd-ca.crt 以示区分，或者直接用)
- apiserver-etcd-client.crt
- apiserver-etcd-client.key
#### Etcd 配置文件 (etcd.config.yml) 写法
注意看 peer 和 client 用了不同的证书：
```
# 1. Peer 通信 (集群同步) -> 用 peer 证书
peer-transport-security:
  cert-file: /etc/etcd/ssl/peer.crt
  key-file: /etc/etcd/ssl/peer.key
  trusted-ca-file: /etc/etcd/ssl/ca.crt
  client-cert-auth: true

# 2. Client 通信 (外部访问) -> 用 server 证书
client-transport-security:
  cert-file: /etc/etcd/ssl/server.crt
  key-file: /etc/etcd/ssl/server.key
  trusted-ca-file: /etc/etcd/ssl/ca.crt
  client-cert-auth: true
```

```
etcdctl \
  --cacert=/etc/etcd/ssl/ca.crt \
  --cert=/etc/etcd/ssl/healthcheck-client.crt \
  --key=/etc/etcd/ssl/healthcheck-client.key \
  --endpoints="https://127.0.0.1:2379" \
  endpoint status
```

#### 下载etcd并放在kubexm/packages/etcd/v${etcd_version}/${arch}/
```
https://github.com/etcd-io/etcd/releases/download/v${etcd_version}/etcd-v${etcd_version}-linux-${arch}.tar.gz
```
#### etcd.service
- 此模板放置在kubexm/templates/etcd/etcd.service.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/etcd/etcd.service
```
cat > /etc/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
Documentation=https://github.com/etcd-io/etcd
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd --config-file /etc/etcd/etcd.config.yml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

#### etcd.config.yml
- 此模板放置在kubexm/templates/etcd/etcd.config.yml.tmpl
- 渲染模板后放置在kubexm/packages/${node_name}/etcd/etcd.config.yml
```
mkdir -p /var/lib/etcd
mkdir -p /etc/etcd

cat > /etc/etcd/etcd.config.yml <<EOF
name: 'etcd-01'
data-dir: '/var/lib/etcd'
wal-dir: ''

# --- 快照与压缩 (生产优化) ---
snapshot-count: 10000
auto-compaction-retention: '1' # 每小时压缩一次
auto-compaction-mode: 'periodic'
quota-backend-bytes: 8589934592 # 8GB 配额 (默认2GB在生产环境容易满)
max-wals: 5

# --- 监听地址 (修改为本机 IP) ---
listen-peer-urls: 'https://192.168.1.10:2380'
listen-client-urls: 'https://192.168.1.10:2379,https://127.0.0.1:2379'

# --- 广播地址 (修改为本机 IP，用于告诉其他节点怎么连我) ---
initial-advertise-peer-urls: 'https://192.168.1.10:2380'
advertise-client-urls: 'https://192.168.1.10:2379'

# --- 集群初始化配置 ---
initial-cluster: 'etcd-01=https://192.168.1.10:2380,etcd-02=https://192.168.1.11:2380,etcd-03=https://192.168.1.12:2380'
initial-cluster-token: 'etcd-k8s-cluster'
initial-cluster-state: 'new'  #以此初始化新集群，如果以后是加入现有集群则填 'existing'

# --- Client 安全配置 (对应 server 证书) ---
client-transport-security:
  cert-file: '/etc/etcd/ssl/server.crt'
  key-file: '/etc/etcd/ssl/server.key'
  trusted-ca-file: '/etc/etcd/ssl/ca.crt'
  client-cert-auth: true

# --- Peer 安全配置 (对应 peer 证书) ---
peer-transport-security:
  cert-file: '/etc/etcd/ssl/peer.crt'
  key-file: '/etc/etcd/ssl/peer.key'
  trusted-ca-file: '/etc/etcd/ssl/ca.crt'
  client-cert-auth: true
  
# --- 调试与日志 ---
logger: 'zap'
log-level: 'info'
EOF
```
#### 分发
- 将对应节点kubexm/packages/${node_name}/certs的证书复制到相应节点的/etc/kubernetes/pki/etcd
- 将对应节点kubexm/packages/${node_name}/etcd/etcd.service复制到相应节点的/etc/systemd/system/etcd.service
- 将对应节点kubexm/packages/${node_name}/etcd/etcd.config.yml复制到相应节点的/etc/etcd/etcd.config.yml
- 启动
  ```
  systemctl daemon-reload
  systemctl enable etcd
  systemctl start etcd
  ```
- 验证etcd
  ```
  # 1. 检查集群成员列表
  ETCDCTL_API=3 etcdctl \
    --cacert=/etc/etcd/ssl/ca.crt \
    --cert=/etc/etcd/ssl/healthcheck-client.crt \
    --key=/etc/etcd/ssl/healthcheck-client.key \
    --endpoints="https://192.168.1.10:2379,https://192.168.1.11:2379,https://192.168.1.12:2379" \
    member list --write-out=table
  
  # 2. 检查 endpoint 健康状态
  ETCDCTL_API=3 etcdctl \
    --cacert=/etc/etcd/ssl/ca.crt \
    --cert=/etc/etcd/ssl/healthcheck-client.crt \
    --key=/etc/etcd/ssl/healthcheck-client.key \
    --endpoints="https://192.168.1.10:2379,https://192.168.1.11:2379,https://192.168.1.12:2379" \
    endpoint health --write-out=table
  ```

## 2. 集群部署详细流程
- 如果kubernetes的type是kubeadm，则需要下载kubeadm kubectl kubelet
- 如果kubernetes的type是kubexm，则需要下载kubeadm kubectl kubelet kube-apiserver kube-controller-manager kube-scheduler、 kube-proxy

### 2.1 场景分类说明
根据 Kubernetes 部署类型、Etcd 部署类型、Master 节点数量以及 LoadBalancer 配置的不同组合，我们将部署场景分为以下几类：

### 2.2 场景1: 单Master集群，LoadBalancer禁用

#### 2.2.1 场景 Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kubeadm 配置模板: `templates/kubernetes/kubeadm/init-master.yaml.tmpl`
   - Kubelet Service 模板: `templates/kubernetes/binary/kubelet/kubelet.service.tmpl`
   - Kubelet 配置模板: `templates/kubernetes/binary/kubelet/10-kubexm-override.conf.tmpl`

2. **模板内容**:

   - Kubeadm-config 配置模板内容** (`templates/kubernetes/kubeadm/init-master.yaml.tmpl`)
   - kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml
   ```yaml
   # ==============================================================================
   # Kubeadm Init Configuration for First Master Node
   # ==============================================================================
   # Generated by KubeXM build system
   # Cluster: ${CLUSTER_NAME}
   # Node: ${NODE_NAME}
   # ==============================================================================
   
   apiVersion: kubeadm.k8s.io/v1beta3
   kind: InitConfiguration
   localAPIEndpoint:
     advertiseAddress: ${NODE_IP}
     bindPort: 6443
   nodeRegistration:
     name: ${NODE_NAME}
     criSocket: ${CRI_SOCKET}
     imagePullPolicy: IfNotPresent
     kubeletExtraArgs:
       node-ip: ${NODE_IP}
       hostname-override: ${NODE_NAME}
     taints:
     - effect: NoSchedule
       key: node-role.kubernetes.io/control-plane
   
   ---
   apiVersion: kubeadm.k8s.io/v1beta3
   kind: ClusterConfiguration
   clusterName: ${CLUSTER_NAME}
   kubernetesVersion: ${KUBERNETES_VERSION}
   controlPlaneEndpoint: "${CONTROL_PLANE_ENDPOINT}:6443"
   certificatesDir: /etc/kubernetes/pki
   imageRepository: ${IMAGE_REPOSITORY}
   networking:
     dnsDomain: ${CLUSTER_DOMAIN}
     serviceSubnet: ${SERVICE_CIDR}
     podSubnet: ${POD_CIDR}
   apiServer:
     extraArgs:
       authorization-mode: Node,RBAC
       enable-admission-plugins: NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
       audit-log-maxage: "30"
       audit-log-maxbackup: "10"
       audit-log-maxsize: "100"
       audit-log-path: /var/log/kubernetes/audit.log
       service-node-port-range: ${SERVICE_NODE_PORT_RANGE}
     extraVolumes:
     - name: audit-log
       hostPath: /var/log/kubernetes
       mountPath: /var/log/kubernetes
       readOnly: false
       pathType: DirectoryOrCreate
     certSANs:
     - "${CONTROL_PLANE_ENDPOINT}"
     - "kubernetes"
     - "kubernetes.default"
     - "kubernetes.default.svc"
     - "kubernetes.default.svc.${CLUSTER_DOMAIN}"
     - "127.0.0.1"
     - "${NODE_IP}"
     ${CERT_SANS}
   controllerManager:
     extraArgs:
       bind-address: 0.0.0.0
       node-cidr-mask-size: "${NODE_CIDR_MASK_SIZE}"
       cluster-signing-duration: "876000h"  # 100 years
     ${CONTROLLER_MANAGER_EXTRA_VOLUMES}
   scheduler:
     extraArgs:
       bind-address: 0.0.0.0
   # 根据etcd类型决定是否配置external etcd
   ${ETCD_CONFIG_BLOCK}
   dns:
     imageRepository: ${IMAGE_REPOSITORY}
     imageTag: ${COREDNS_VERSION}
   
   ---
   apiVersion: kubelet.config.k8s.io/v1beta1
   kind: KubeletConfiguration
   authentication:
     anonymous:
       enabled: false
     webhook:
       enabled: true
     x509:
       clientCAFile: /etc/kubernetes/pki/ca.crt
   authorization:
     mode: Webhook
   clusterDNS:
   - ${CLUSTER_DNS_IP}
   clusterDomain: ${CLUSTER_DOMAIN}
   cgroupDriver: systemd
   containerRuntimeEndpoint: ${CRI_SOCKET}
   maxPods: ${MAX_PODS}
   podCIDR: ${POD_CIDR}
   resolvConf: /etc/resolv.conf
   rotateCertificates: true
   runtimeRequestTimeout: 15m
   serverTLSBootstrap: true
   tlsCertFile: /var/lib/kubelet/pki/kubelet.crt
   tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet.key
   
   ---
   apiVersion: kubeproxy.config.k8s.io/v1alpha1
   kind: KubeProxyConfiguration
   bindAddress: 0.0.0.0
   clientConnection:
     kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
   clusterCIDR: ${POD_CIDR}
   mode: ${KUBE_PROXY_MODE}
   ipvs:
     strictARP: true
   iptables:
     masqueradeAll: false
     masqueradeBit: 14
     minSyncPeriod: 0s
     syncPeriod: 30s
   ```
   - kubelet.service 配置模板内容** (`templates/kubernetes/kubelet/kubelet-kubeadm.service.tmpl`)
   - kubelet.service渲染后的内容放置在kubexm/packages/${node_name}/kubelet.service
   ```
    [Unit]
    Description=kubelet: The Kubernetes Node Agent
    Documentation=http://kubernetes.io/docs/
    
    [Service]
    CPUAccounting=true
    MemoryAccounting=true
    ExecStart=/usr/local/bin/kubelet
    Restart=always
    StartLimitInterval=0
    RestartSec=10
    
    [Install]
    WantedBy=multi-user.target
   ```

   - 10-kubexm-kubeadm.conf 配置模板内容** (`templates/kubernetes/kubelet/10-kubexm-kubeadm.conf.tmpl`)
   - 10-kubexm-kubeadm.conf渲染后的内容放置在kubexm/packages/${node_name}/10-kubexm-kubeadm.conf
   ```
    # Note: This dropin only works with kubeadm and kubelet v1.11+
    [Service]
    Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
    Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
    # This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
    EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
    # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
    # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
    EnvironmentFile=-/etc/default/kubelet
    Environment="KUBELET_EXTRA_ARGS=--node-ip=172.30.1.16 --hostname-override=node5 "
    ExecStart=
    ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
   ```


3. **渲染模板**:
   - 使用配置参数渲染 kubeadm 配置文件,kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml
   - 使用节点特定参数渲染 kubelet.service,渲染后的内容放置在kubexm/packages/${node_name}/kubelet.service
   - 使用节点特定参数渲染 10-kubexm-kubeadm.conf,渲染后的内容放置在kubexm/packages/${node_name}/10-kubexm-kubeadm.conf

4. **分发**:
   - 将kubexm/packages/kubernetes/${kubernetes_version}/${arch}/kubelet二进制文件分发到响应的节点
   - 将渲染后的 kubeadm-config.yaml从kubexm/packages/${node_name}/kubeadm-config.yaml复制到对应节点的/etc/kubernetes/kubeadm-config.yaml
   - 将 kubelet.service从kubexm/packages/${node_name}/kubelet.service复制到对应节点的/etc/systemd/system/kubelet.service
   - 将 kubelet.service从kubexm/packages/${node_name}/10-kubexm-kubeadm.conf复制到对应节点的/etc/systemd/system/kubelet.service.d/10-kubexm-kubeadm.conf

5. **初始化集群**:
   ```
   kubeadm init --config=/etc/kubernetes/kubeadm-config.yaml
   ```

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

#### 2.2.2 场景 Kubernetes=kubexm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubexm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kube-apiserver Service 模板: `templates/kubernetes/kube-apiserver/kube-apiserver.service.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/kube-apiserver.service
    ```
    [Unit]
    Description=Kubernetes API Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target
   
    [Service]
    ExecStart=/opt/kube/bin/kube-apiserver \
      --allow-privileged=true \
      --anonymous-auth=false \
      --api-audiences=api,istio-ca \
      --authorization-mode=Node,RBAC \
      --bind-address=10.200.200.170 \
      --client-ca-file=/etc/kubernetes/ssl/ca.pem \
      --endpoint-reconciler-type=lease \
      --etcd-cafile=/etc/kubernetes/ssl/ca.pem \
      --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem \
      --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem \
      --etcd-servers=https://10.200.200.170:2379 \
      --kubelet-certificate-authority=/etc/kubernetes/ssl/ca.pem \
      --kubelet-client-certificate=/etc/kubernetes/ssl/kubernetes.pem \
      --kubelet-client-key=/etc/kubernetes/ssl/kubernetes-key.pem \
      --secure-port=6443 \
      --service-account-issuer=https://kubernetes.default.svc \
      --service-account-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \
      --service-account-key-file=/etc/kubernetes/ssl/ca.pem \
      --service-cluster-ip-range=10.68.0.0/16 \
      --service-node-port-range=30000-32767 \
      --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
      --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
      --requestheader-client-ca-file=/etc/kubernetes/ssl/ca.pem \
      --requestheader-allowed-names= \
      --requestheader-extra-headers-prefix=X-Remote-Extra- \
      --requestheader-group-headers=X-Remote-Group \
      --requestheader-username-headers=X-Remote-User \
      --proxy-client-cert-file=/etc/kubernetes/ssl/aggregator-proxy.pem \
      --proxy-client-key-file=/etc/kubernetes/ssl/aggregator-proxy-key.pem \
      --enable-aggregator-routing=true \
      --v=2
    Restart=always
    RestartSec=5
    Type=notify
    LimitNOFILE=65536
   
    [Install]
    WantedBy=multi-user.target
    ```
   - Kube-controller-manager Service 模板: `templates/kubernetes/kube-controller-manager/kube-controller-manager.service.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/kube-controller-manager.service
   ```
    [Unit]
    Description=Kubernetes Controller Manager
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
   
    [Service]
    ExecStart=/opt/kube/bin/kube-controller-manager \
      --allocate-node-cidrs=true \
      --authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
      --authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
      --bind-address=0.0.0.0 \
      --cluster-cidr=172.20.0.0/16 \
      --cluster-name=kubernetes \
      --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
      --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \
      --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \
      --leader-elect=true \
      --node-cidr-mask-size=24 \
      --root-ca-file=/etc/kubernetes/ssl/ca.pem \
      --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem \
      --service-cluster-ip-range=10.68.0.0/16 \
      --use-service-account-credentials=true \
      --v=2
    Restart=always
    RestartSec=5
   
    [Install]
    WantedBy=multi-user.target
   ```
   - Kube-scheduler Service 模板: `templates/kubernetes/kube-scheduler/kube-scheduler.service.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/kube-scheduler.service
   ```
    [Unit]
    Description=Kubernetes Scheduler
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
   
    [Service]
    ExecStart=/opt/kube/bin/kube-scheduler \
      --authentication-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \
      --authorization-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \
      --bind-address=0.0.0.0 \
      --kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \
      --leader-elect=true \
      --v=2
    Restart=always
    RestartSec=5
   
    [Install]
    WantedBy=multi-user.target
   ```
   - Kube-proxy Service 模板: `templates/kubernetes/kube-proxy/kube-proxy.service.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/kube-proxy.service
   ```
    [Unit]
    Description=Kubernetes Kube-Proxy Server
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
    After=network.target
   
    [Service]
    WorkingDirectory=/var/lib/kube-proxy
    ExecStart=/opt/kube/bin/kube-proxy \
      --config=/var/lib/kube-proxy/kube-proxy-config.yaml
    Restart=always
    RestartSec=5
    LimitNOFILE=65536
   
    [Install]
    WantedBy=multi-user.target
   ```

   - kube-proxy-config.yaml 模板: `templates/kubernetes/kube-proxy/kube-proxy-config.yaml.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/kube-proxy-config.yaml
   ```
    kind: KubeProxyConfiguration
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    bindAddress: 0.0.0.0
    clientConnection:
      kubeconfig: "/etc/kubernetes/kube-proxy.kubeconfig"
    # 根据clusterCIDR 判断集群内部和外部流量，配置clusterCIDR选项后，kube-proxy 会对访问 Service IP 的请求做 SNAT
    clusterCIDR: "172.20.0.0/16"
    conntrack:
      maxPerCore: 32768
      min: 131072
      tcpCloseWaitTimeout: 1h0m0s
      tcpEstablishedTimeout: 24h0m0s
    healthzBindAddress: 0.0.0.0:10256
    # hostnameOverride 值必须与 kubelet 的对应一致，否则 kube-proxy 启动后会找不到该 Node，从而不会创建任何 iptables 规则
    hostnameOverride: "tf-vm4"
    metricsBindAddress: 0.0.0.0:10249
    mode: "ipvs"
    ipvs:
      excludeCIDRs: null
      minSyncPeriod: 0s
      scheduler: ""
      strictARP: False
      syncPeriod: 30s
      tcpFinTimeout: 0s
      tcpTimeout: 0s
      udpTimeout: 0s
   ```

   - Kubelet Service 模板: `templates/kubernetes/kubelet/kubelet-binary.service.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/kubelet.service
   ```
    [Unit]
    Description=Kubernetes Kubelet
    Documentation=https://github.com/GoogleCloudPlatform/kubernetes
   
    [Service]
    WorkingDirectory=/var/lib/kubelet
    ExecStartPre=/bin/mount -o remount,rw '/sys/fs/cgroup'
    ExecStart=/opt/kube/bin/kubelet \
      --config=/var/lib/kubelet/config.yaml \
      --container-runtime-endpoint=unix:///run/containerd/containerd.sock \
      --hostname-override=tf-vm4 \
      --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
      --root-dir=/var/lib/kubelet \
      --v=2
    Restart=always
    RestartSec=5
   
    [Install]
    WantedBy=multi-user.target
   ```

   - Kubelet config 模板: `templates/kubernetes/binary/kubelet/kubelet-binary-config.yaml.tmpl`
   - 模板渲染后放在kubexm/packages/${node_name}/config.yaml
   ```
    kind: KubeletConfiguration
    apiVersion: kubelet.config.k8s.io/v1beta1
    address: 0.0.0.0
    authentication:
      anonymous:
        enabled: false
      webhook:
        cacheTTL: 2m0s
        enabled: true
      x509:
        clientCAFile: /etc/kubernetes/ssl/ca.pem
    authorization:
      mode: Webhook
      webhook:
        cacheAuthorizedTTL: 5m0s
        cacheUnauthorizedTTL: 30s
    cgroupDriver: systemd
    cgroupsPerQOS: true
    clusterDNS:
    - 169.254.20.10
    clusterDomain: cluster.local
    configMapAndSecretChangeDetectionStrategy: Watch
    containerLogMaxFiles: 3
    containerLogMaxSize: 10Mi
    enforceNodeAllocatable:
    - pods
    eventBurst: 10
    eventRecordQPS: 5
    evictionHard:
      imagefs.available: 15%
      memory.available: 300Mi
      nodefs.available: 10%
      nodefs.inodesFree: 5%
    evictionPressureTransitionPeriod: 5m0s
    failSwapOn: true
    fileCheckFrequency: 40s
    hairpinMode: hairpin-veth
    healthzBindAddress: 0.0.0.0
    healthzPort: 10248
    httpCheckFrequency: 40s
    imageGCHighThresholdPercent: 85
    imageGCLowThresholdPercent: 80
    imageMinimumGCAge: 2m0s
    kubeAPIBurst: 100
    kubeAPIQPS: 50
    makeIPTablesUtilChains: true
    maxOpenFiles: 1000000
    maxParallelImagePulls: 5
    maxPods: 110
    nodeLeaseDurationSeconds: 40
    nodeStatusReportFrequency: 1m0s
    nodeStatusUpdateFrequency: 10s
    oomScoreAdj: -999
    podPidsLimit: -1
    port: 10250
    # disable readOnlyPort
    readOnlyPort: 0
    resolvConf: /run/systemd/resolve/resolv.conf
    runtimeRequestTimeout: 2m0s
    serializeImagePulls: false
    streamingConnectionIdleTimeout: 4h0m0s
    syncFrequency: 1m0s
    tlsCertFile: /etc/kubernetes/ssl/kubelet.pem
    tlsPrivateKeyFile: /etc/kubernetes/ssl/kubelet-key.pem
   ```

    - 此模板放置在kubexm/templates/etcd/etcd.service.tmpl
    - 渲染模板后放置在kubexm/packages/${node_name}/etcd/etcd.service
    ```
    cat > /etc/systemd/system/etcd.service <<EOF
    [Unit]
    Description=Etcd Server
    Documentation=https://github.com/etcd-io/etcd
    After=network.target network-online.target
    Wants=network-online.target
    
    [Service]
    Type=notify
    ExecStart=/usr/local/bin/etcd --config-file /etc/etcd/etcd.config.yml
    Restart=on-failure
    RestartSec=5
    LimitNOFILE=65536
    
    [Install]
    WantedBy=multi-user.target
    EOF
    ```

    - 此模板放置在kubexm/templates/etcd/etcd.config.yml.tmpl
    - 渲染模板后放置在kubexm/packages/${node_name}/etcd/etcd.config.yml
    ```
    mkdir -p /var/lib/etcd
    mkdir -p /etc/etcd
    
    cat > /etc/etcd/etcd.config.yml <<EOF
    name: 'etcd-01'
    data-dir: '/var/lib/etcd'
    wal-dir: ''
    
    # --- 快照与压缩 (生产优化) ---
    snapshot-count: 10000
    auto-compaction-retention: '1' # 每小时压缩一次
    auto-compaction-mode: 'periodic'
    quota-backend-bytes: 8589934592 # 8GB 配额 (默认2GB在生产环境容易满)
    max-wals: 5
    
    # --- 监听地址 (修改为本机 IP) ---
    listen-peer-urls: 'https://192.168.1.10:2380'
    listen-client-urls: 'https://192.168.1.10:2379,https://127.0.0.1:2379'
    
    # --- 广播地址 (修改为本机 IP，用于告诉其他节点怎么连我) ---
    initial-advertise-peer-urls: 'https://192.168.1.10:2380'
    advertise-client-urls: 'https://192.168.1.10:2379'
    
    # --- 集群初始化配置 ---
    initial-cluster: 'etcd-01=https://192.168.1.10:2380,etcd-02=https://192.168.1.11:2380,etcd-03=https://192.168.1.12:2380'
    initial-cluster-token: 'etcd-k8s-cluster'
    initial-cluster-state: 'new'  #以此初始化新集群，如果以后是加入现有集群则填 'existing'
    
    # --- Client 安全配置 (对应 server 证书) ---
    client-transport-security:
      cert-file: '/etc/etcd/ssl/server.crt'
      key-file: '/etc/etcd/ssl/server.key'
      trusted-ca-file: '/etc/etcd/ssl/ca.crt'
      client-cert-auth: true
    
    # --- Peer 安全配置 (对应 peer 证书) ---
    peer-transport-security:
      cert-file: '/etc/etcd/ssl/peer.crt'
      key-file: '/etc/etcd/ssl/peer.key'
      trusted-ca-file: '/etc/etcd/ssl/ca.crt'
      client-cert-auth: true
      
    # --- 调试与日志 ---
    logger: 'zap'
    log-level: 'info'
    EOF
    ```

2. **模板内容**:

   **Etcd Service 模板内容** (`templates/etcd/etcd.service.tmpl`):
   ```ini
   [Unit]
   Description=etcd
   After=network.target

   [Service]
   User=root
   Type=notify
   EnvironmentFile=/etc/etcd.env
   ExecStart=/usr/local/bin/etcd
   NotifyAccess=all
   RestartSec=10s
   LimitNOFILE=40000
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

   **Kubelet Service 模板内容** (`templates/kubernetes/binary/kubelet/kubelet.service.tmpl`):
   ```ini
   [Unit]
   Description=kubelet: The Kubernetes Node Agent
   Documentation=http://kubernetes.io/docs/

   [Service]
   CPUAccounting=true
   MemoryAccounting=true
   ExecStart=/usr/local/bin/kubelet
   Restart=always
   StartLimitInterval=0
   RestartSec=10

   [Install]
   WantedBy=multi-user.target
   ```

3. **渲染模板**:
   - 使用配置参数渲染所有组件的 service 和配置文件

4. **分发配置**:
   - 将所有渲染后的配置文件和服务文件分发到相应节点

5. **启动服务**:
   - 在 Etcd 节点启动 etcd 服务
   - 在 Master 节点依次启动 kube-apiserver、kube-controller-manager、kube-scheduler
   - 在所有节点启动 kubelet 和 kube-proxy

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

#### 2.2.3 场景 Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kubeadm 配置模板: `templates/kubernetes/kubeadm/init-master.yaml.tmpl`
   
   - kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml

     ```
        # ==============================================================================
        # Kubeadm Init Configuration for First Master Node
        # ==============================================================================
        # Generated by KubeXM build system
        # Cluster: ${CLUSTER_NAME}
        # Node: ${NODE_NAME}
        # ==============================================================================
        
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: InitConfiguration
        localAPIEndpoint:
          advertiseAddress: ${NODE_IP}
          bindPort: 6443
        nodeRegistration:
          name: ${NODE_NAME}
          criSocket: ${CRI_SOCKET}
          imagePullPolicy: IfNotPresent
          kubeletExtraArgs:
            node-ip: ${NODE_IP}
            hostname-override: ${NODE_NAME}
          taints:
          - effect: NoSchedule
            key: node-role.kubernetes.io/control-plane
        
        ---
        apiVersion: kubeadm.k8s.io/v1beta3
        kind: ClusterConfiguration
        clusterName: ${CLUSTER_NAME}
        kubernetesVersion: ${KUBERNETES_VERSION}
        controlPlaneEndpoint: "${CONTROL_PLANE_ENDPOINT}:6443"
        certificatesDir: /etc/kubernetes/pki
        imageRepository: ${IMAGE_REPOSITORY}
        networking:
          dnsDomain: ${CLUSTER_DOMAIN}
          serviceSubnet: ${SERVICE_CIDR}
          podSubnet: ${POD_CIDR}
        apiServer:
          extraArgs:
            authorization-mode: Node,RBAC
            enable-admission-plugins: NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
            audit-log-maxage: "30"
            audit-log-maxbackup: "10"
            audit-log-maxsize: "100"
            audit-log-path: /var/log/kubernetes/audit.log
            service-node-port-range: ${SERVICE_NODE_PORT_RANGE}
          extraVolumes:
          - name: audit-log
            hostPath: /var/log/kubernetes
            mountPath: /var/log/kubernetes
            readOnly: false
            pathType: DirectoryOrCreate
          certSANs:
          - "${CONTROL_PLANE_ENDPOINT}"
          - "kubernetes"
          - "kubernetes.default"
          - "kubernetes.default.svc"
          - "kubernetes.default.svc.${CLUSTER_DOMAIN}"
          - "127.0.0.1"
          - "${NODE_IP}"
          ${CERT_SANS}
        controllerManager:
          extraArgs:
            bind-address: 0.0.0.0
            node-cidr-mask-size: "${NODE_CIDR_MASK_SIZE}"
            cluster-signing-duration: "876000h"  # 100 years
          ${CONTROLLER_MANAGER_EXTRA_VOLUMES}
        scheduler:
          extraArgs:
            bind-address: 0.0.0.0
        # 根据etcd类型决定是否配置external etcd
        ${ETCD_CONFIG_BLOCK}
        dns:
          imageRepository: ${IMAGE_REPOSITORY}
          imageTag: ${COREDNS_VERSION}
        
        ---
        apiVersion: kubelet.config.k8s.io/v1beta1
        kind: KubeletConfiguration
        authentication:
          anonymous:
            enabled: false
          webhook:
            enabled: true
          x509:
            clientCAFile: /etc/kubernetes/pki/ca.crt
        authorization:
          mode: Webhook
        clusterDNS:
        - ${CLUSTER_DNS_IP}
        clusterDomain: ${CLUSTER_DOMAIN}
        cgroupDriver: systemd
        containerRuntimeEndpoint: ${CRI_SOCKET}
        maxPods: ${MAX_PODS}
        podCIDR: ${POD_CIDR}
        resolvConf: /etc/resolv.conf
        rotateCertificates: true
        runtimeRequestTimeout: 15m
        serverTLSBootstrap: true
        tlsCertFile: /var/lib/kubelet/pki/kubelet.crt
        tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet.key
        
        ---
        apiVersion: kubeproxy.config.k8s.io/v1alpha1
        kind: KubeProxyConfiguration
        bindAddress: 0.0.0.0
        clientConnection:
          kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
        clusterCIDR: ${POD_CIDR}
        mode: ${KUBE_PROXY_MODE}
        ipvs:
          strictARP: true
        iptables:
          masqueradeAll: false
          masqueradeBit: 14
          minSyncPeriod: 0s
          syncPeriod: 30s
     ```
   
     
   
   - Etcd Service 模板: 不需要，etcd由kubeadm管理
   
   - kubelet.service 配置模板内容** (`templates/kubernetes/kubelet/kubelet-kubeadm.service.tmpl`)
   
   - kubelet.service渲染后的内容放置在kubexm/packages/${node_name}/kubelet.service
   
     ```
         [Unit]
         Description=kubelet: The Kubernetes Node Agent
         Documentation=http://kubernetes.io/docs/
         
         [Service]
         CPUAccounting=true
         MemoryAccounting=true
         ExecStart=/usr/local/bin/kubelet
         Restart=always
         StartLimitInterval=0
         RestartSec=10
         
         [Install]
         WantedBy=multi-user.target
     ```
   
     
   
   - 10-kubexm-kubeadm.conf 配置模板内容** (`templates/kubernetes/kubelet/10-kubexm-kubeadm.conf.tmpl`)
   
      - 10-kubexm-kubeadm.conf渲染后的内容放置在kubexm/packages/${node_name}/10-kubexm-kubeadm.conf
   
        ```
            # Note: This dropin only works with kubeadm and kubelet v1.11+
            [Service]
            Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
            Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
            # This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
            EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
            # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
            # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
            EnvironmentFile=-/etc/default/kubelet
            Environment="KUBELET_EXTRA_ARGS=--node-ip=172.30.1.16 --hostname-override=node5 "
            ExecStart=
            ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
        ```
   
        
   
        
   
2. **模板内容**:
   同场景1.1和1.2中的模板内容。

3. **渲染模板**:
   - 使用配置参数渲染 kubeadm 配置文件
   - 使用节点特定参数渲染 etcd 和 kubelet 的 service 文件

4. **分发配置**:
   - 将渲染后的配置文件分发到相应节点

5. **启动服务**:
   - 在 Etcd 节点启动 etcd 服务
   - 在 Master 节点执行 kubeadm 初始化

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

#### 2.2.4 场景 Kubernetes=kubeadm, Etcd=exist
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = exist`
- `spec.etcd.external_endpoints` 必须配置
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kubeadm-config 配置模板内容** (`templates/kubernetes/kubeadm/init-master.yaml.tmpl`)
   
      - kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml
   
      - 这种情况etcd已经存在了，不需要部署etcd
   
        ```
        ---
        apiVersion: kubeadm.k8s.io/v1beta2
        kind: ClusterConfiguration
        etcd:
          external:
            endpoints:
            - https://172.30.1.12:2379
            - https://172.30.1.14:2379
            - https://172.30.1.15:2379
            caFile: /etc/ssl/etcd/ssl/ca.pem
            certFile: /etc/ssl/etcd/ssl/node-node2.pem
            keyFile: /etc/ssl/etcd/ssl/node-node2-key.pem
        dns:
          type: CoreDNS
          imageRepository: dockerhub.kubekey.local/kubesphereio
          imageTag: 1.8.6
        imageRepository: dockerhub.kubekey.local/kubesphereio
        kubernetesVersion: v1.24.9
        certificatesDir: /etc/kubernetes/pki
        clusterName: cluster.local
        controlPlaneEndpoint: lb.kubesphere.local:6443
        networking:
          dnsDomain: cluster.local
          podSubnet: 10.233.64.0/18
          serviceSubnet: 10.233.0.0/18
        apiServer:
          extraArgs:
            audit-log-maxage: "30"
            audit-log-maxbackup: "10"
            audit-log-maxsize: "100"
            bind-address: 0.0.0.0
            feature-gates: RotateKubeletServerCertificate=true,ExpandCSIVolumes=true,CSIStorageCapacity=true
          certSANs:
            - kubernetes
            - kubernetes.default
            - kubernetes.default.svc
            - kubernetes.default.svc.cluster.local
            - localhost
            - 127.0.0.1
            - lb.kubesphere.local
            - 172.30.1.12
            - node1
            - node1.cluster.local
            - 172.30.1.13
            - node2
            - node2.cluster.local
            - node3
            - node3.cluster.local
            - 172.30.1.14
            - node4
            - node4.cluster.local
            - 172.30.1.15
            - node5
            - node5.cluster.local
            - 172.30.1.16
            - node7
            - node7.cluster.local
            - 172.30.1.17
            - node8
            - node8.cluster.local
            - 172.30.1.18
            - node9
            - node9.cluster.local
            - 172.30.1.19
            - 10.233.0.1
        controllerManager:
          extraArgs:
            node-cidr-mask-size: "24"
            bind-address: 0.0.0.0
            cluster-signing-duration: 87600h
            feature-gates: RotateKubeletServerCertificate=true,ExpandCSIVolumes=true,CSIStorageCapacity=true
          extraVolumes:
          - name: host-time
            hostPath: /etc/localtime
            mountPath: /etc/localtime
            readOnly: true
        scheduler:
          extraArgs:
            bind-address: 0.0.0.0
            feature-gates: RotateKubeletServerCertificate=true,ExpandCSIVolumes=true,CSIStorageCapacity=true
        
        ---
        apiVersion: kubeadm.k8s.io/v1beta2
        kind: InitConfiguration
        localAPIEndpoint:
          advertiseAddress: 172.30.1.12
          bindPort: 6443
        nodeRegistration:
          criSocket: unix:///run/containerd/containerd.sock
          kubeletExtraArgs:
            cgroup-driver: systemd
        ---
        apiVersion: kubeproxy.config.k8s.io/v1alpha1
        kind: KubeProxyConfiguration
        clusterCIDR: 10.233.64.0/18
        iptables:
          masqueradeAll: false
          masqueradeBit: 14
          minSyncPeriod: 0s
          syncPeriod: 30s
        mode: iptables
        ---
        apiVersion: kubelet.config.k8s.io/v1beta1
        kind: KubeletConfiguration
        clusterDNS:
        - 169.254.25.10
        clusterDomain: cluster.local
        containerLogMaxFiles: 3
        containerLogMaxSize: 5Mi
        evictionHard:
          memory.available: 5%
          pid.available: 10%
        evictionMaxPodGracePeriod: 120
        evictionPressureTransitionPeriod: 30s
        evictionSoft:
          memory.available: 10%
        evictionSoftGracePeriod:
          memory.available: 2m
        featureGates:
          CSIStorageCapacity: true
          ExpandCSIVolumes: true
          RotateKubeletServerCertificate: true
        kubeReserved:
          cpu: 200m
          memory: 250Mi
        maxPods: 110
        podPidsLimit: 10000
        rotateCertificates: true
        systemReserved:
          cpu: 200m
          memory: 250Mi
        
        ```
   
        
   
   - kubelet.service 配置模板内容** (`templates/kubernetes/kubelet/kubelet-kubeadm.service.tmpl`)
   
      - kubelet.service渲染后的内容放置在kubexm/packages/${node_name}/kubelet.service
   
      ```
       [Unit]
       Description=kubelet: The Kubernetes Node Agent
       Documentation=http://kubernetes.io/docs/
       
       [Service]
       CPUAccounting=true
       MemoryAccounting=true
       ExecStart=/usr/local/bin/kubelet
       Restart=always
       StartLimitInterval=0
       RestartSec=10
       
       [Install]
       WantedBy=multi-user.target
      ```
   
      - 10-kubexm-kubeadm.conf 配置模板内容** (`templates/kubernetes/kubelet/10-kubexm-kubeadm.conf.tmpl`)
      - 10-kubexm-kubeadm.conf渲染后的内容放置在kubexm/packages/${node_name}/10-kubexm-kubeadm.conf
      ```
       # Note: This dropin only works with kubeadm and kubelet v1.11+
       [Service]
       Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
       Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
       # This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
       EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
       # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
       # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
       EnvironmentFile=-/etc/default/kubelet
       Environment="KUBELET_EXTRA_ARGS=--node-ip=172.30.1.16 --hostname-override=node5 "
       ExecStart=
       ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
      ```
   
2. **模板内容**:
   同场景1.1中的模板内容。

3. **渲染模板**:
   - 使用配置参数渲染 kubeadm 配置文件，其中包含外部 etcd 的配置
   - 使用节点特定参数渲染 kubelet service 文件

4. **分发配置**:
   - 将渲染后的 kubeadm 配置文件分发到 master 节点
   - 将 kubelet service 文件分发到所有节点

5. **初始化集群**:
   ```
   kubeadm init --config=/etc/kubernetes/kubeadm-config.yaml
   ```

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

### 2.3 场景2: 多Master集群，LoadBalancer禁用

#### 2.3.1 场景 Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kubeadm-config 配置模板内容** (`templates/kubernetes/kubeadm/init-master.yaml.tmpl`)
      - kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml
   
      ```yaml
      # ==============================================================================
      # Kubeadm Init Configuration for First Master Node
      # ==============================================================================
      # Generated by KubeXM build system
      # Cluster: ${CLUSTER_NAME}
      # Node: ${NODE_NAME}
      # ==============================================================================
      
      apiVersion: kubeadm.k8s.io/v1beta3
      kind: InitConfiguration
      localAPIEndpoint:
        advertiseAddress: ${NODE_IP}
        bindPort: 6443
      nodeRegistration:
        name: ${NODE_NAME}
        criSocket: ${CRI_SOCKET}
        imagePullPolicy: IfNotPresent
        kubeletExtraArgs:
          node-ip: ${NODE_IP}
          hostname-override: ${NODE_NAME}
        taints:
        - effect: NoSchedule
          key: node-role.kubernetes.io/control-plane
      
      ---
      apiVersion: kubeadm.k8s.io/v1beta3
      kind: ClusterConfiguration
      clusterName: ${CLUSTER_NAME}
      kubernetesVersion: ${KUBERNETES_VERSION}
      controlPlaneEndpoint: "${CONTROL_PLANE_ENDPOINT}:6443"
      certificatesDir: /etc/kubernetes/pki
      imageRepository: ${IMAGE_REPOSITORY}
      networking:
        dnsDomain: ${CLUSTER_DOMAIN}
        serviceSubnet: ${SERVICE_CIDR}
        podSubnet: ${POD_CIDR}
      apiServer:
        extraArgs:
          authorization-mode: Node,RBAC
          enable-admission-plugins: NodeRestriction,NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
          audit-log-maxage: "30"
          audit-log-maxbackup: "10"
          audit-log-maxsize: "100"
          audit-log-path: /var/log/kubernetes/audit.log
          service-node-port-range: ${SERVICE_NODE_PORT_RANGE}
        extraVolumes:
        - name: audit-log
          hostPath: /var/log/kubernetes
          mountPath: /var/log/kubernetes
          readOnly: false
          pathType: DirectoryOrCreate
        certSANs:
        - "${CONTROL_PLANE_ENDPOINT}"
        - "kubernetes"
        - "kubernetes.default"
        - "kubernetes.default.svc"
        - "kubernetes.default.svc.${CLUSTER_DOMAIN}"
        - "127.0.0.1"
        - "${NODE_IP}"
        ${CERT_SANS}
      controllerManager:
        extraArgs:
          bind-address: 0.0.0.0
          node-cidr-mask-size: "${NODE_CIDR_MASK_SIZE}"
          cluster-signing-duration: "876000h"  # 100 years
        ${CONTROLLER_MANAGER_EXTRA_VOLUMES}
      scheduler:
        extraArgs:
          bind-address: 0.0.0.0
      # 根据etcd类型决定是否配置external etcd
      ${ETCD_CONFIG_BLOCK}
      dns:
        imageRepository: ${IMAGE_REPOSITORY}
        imageTag: ${COREDNS_VERSION}
      
      ---
      apiVersion: kubelet.config.k8s.io/v1beta1
      kind: KubeletConfiguration
      authentication:
        anonymous:
          enabled: false
        webhook:
          enabled: true
        x509:
          clientCAFile: /etc/kubernetes/pki/ca.crt
      authorization:
        mode: Webhook
      clusterDNS:
      - ${CLUSTER_DNS_IP}
      clusterDomain: ${CLUSTER_DOMAIN}
      cgroupDriver: systemd
      containerRuntimeEndpoint: ${CRI_SOCKET}
      maxPods: ${MAX_PODS}
      podCIDR: ${POD_CIDR}
      resolvConf: /etc/resolv.conf
      rotateCertificates: true
      runtimeRequestTimeout: 15m
      serverTLSBootstrap: true
      tlsCertFile: /var/lib/kubelet/pki/kubelet.crt
      tlsPrivateKeyFile: /var/lib/kubelet/pki/kubelet.key
      
      ---
      apiVersion: kubeproxy.config.k8s.io/v1alpha1
      kind: KubeProxyConfiguration
      bindAddress: 0.0.0.0
      clientConnection:
        kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
      clusterCIDR: ${POD_CIDR}
      mode: ${KUBE_PROXY_MODE}
      ipvs:
        strictARP: true
      iptables:
        masqueradeAll: false
        masqueradeBit: 14
        minSyncPeriod: 0s
        syncPeriod: 30s
      ```
   
   - 其他 Master 的 Kubeadm 配置模板: `templates/kubernetes/kubeadm/join-master.yaml.tmpl`
   
      - kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml
   
        ```
        ---
        apiVersion: kubeadm.k8s.io/v1beta2
        kind: JoinConfiguration
        discovery:
          bootstrapToken:
            apiServerEndpoint: {{ .ApiServerEndpoint }}
            token: "{{ .Token }}"
            unsafeSkipCAVerification: {{ .UnsafeSkipCAVerification }}
          tlsBootstrapToken: "{{ .TLSBootstrapToken }}"
        controlPlane:
          localAPIEndpoint:
            advertiseAddress: {{ .AdvertiseAddress }}
            bindPort: {{ .BindPort }}
          certificateKey: {{ .CertificateKey }}
        nodeRegistration:
          criSocket: {{ .CriSocket }}
          kubeletExtraArgs:
            cgroup-driver: {{ .CgroupDriver }}
        ```
   
        
   
   - Worker 节点的 Kubeadm 配置模板: `templates/kubernetes/kubeadm/join-worker.yaml.tmpl`
   
   - kubeadm-config渲染后的内容放置在kubexm/packages/${node_name}/kubeadm-config.yaml
   
     ```
     ---
     apiVersion: kubeadm.k8s.io/v1beta2
     kind: JoinConfiguration
     discovery:
       bootstrapToken:
         apiServerEndpoint: {{ .ApiServerEndpoint }}
         token: "{{ .Token }}"
         unsafeSkipCAVerification: {{ .UnsafeSkipCAVerification }}
       tlsBootstrapToken: "{{ .TLSBootstrapToken }}"
     nodeRegistration:
       criSocket: {{ .CriSocket }}
       kubeletExtraArgs:
         cgroup-driver: {{ .CgroupDriver }}
     ```
   
     
   
   - kubelet.service 配置模板内容** (`templates/kubernetes/kubelet/kubelet-kubeadm.service.tmpl`)
   
      - kubelet.service渲染后的内容放置在kubexm/packages/${node_name}/kubelet.service
   
      ```
       [Unit]
       Description=kubelet: The Kubernetes Node Agent
       Documentation=http://kubernetes.io/docs/
       
       [Service]
       CPUAccounting=true
       MemoryAccounting=true
       ExecStart=/usr/local/bin/kubelet
       Restart=always
       StartLimitInterval=0
       RestartSec=10
       
       [Install]
       WantedBy=multi-user.target
      ```
   
      - 10-kubexm-kubeadm.conf 配置模板内容** (`templates/kubernetes/kubelet/10-kubexm-kubeadm.conf.tmpl`)
      - 10-kubexm-kubeadm.conf渲染后的内容放置在kubexm/packages/${node_name}/10-kubexm-kubeadm.conf
      ```
       # Note: This dropin only works with kubeadm and kubelet v1.11+
       [Service]
       Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
       Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
       # This is a file that "kubeadm init" and "kubeadm join" generate at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
       EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
       # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
       # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
       EnvironmentFile=-/etc/default/kubelet
       Environment="KUBELET_EXTRA_ARGS=--node-ip=172.30.1.16 --hostname-override=node5 "
       ExecStart=
       ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
      ```
   
   
   
3. **渲染模板**:
   - 使用配置参数渲染所有节点的 kubeadm 配置文件
   - 使用节点特定参数渲染 kubelet service 文件

4. **分发配置**:
   - 将渲染后的配置文件分发到相应节点

5. **初始化集群**:
   - 在第一台 Master 节点执行 kubeadm 初始化
   - 获取 join token 和 certificate key
   - 在其他 Master 节点执行 kubeadm join（控制平面）
   - 在 Worker 节点执行 kubeadm join

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

#### 2.3.2 场景 Kubernetes=kubexm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubexm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - 所有 Kubernetes 组件的 Service 模板（同场景2.2.2）
   - Etcd Service 模板: `（同场景2.2.2）`

2. **模板内容**:
   同场景1.2中的模板内容。

3. **渲染模板**:
   - 使用配置参数渲染所有组件的 service 和配置文件

4. **分发配置**:
   - 将所有渲染后的配置文件和服务文件分发到相应节点

5. **启动服务**:
   - 在所有 Etcd 节点启动 etcd 服务并组建集群
   - 在所有 Master 节点依次启动 kube-apiserver、kube-controller-manager、kube-scheduler
   - 在所有节点启动 kubelet 和 kube-proxy

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

#### 2.3.3 场景 Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kubeadm 配置模板（同场景2.1）
   - Etcd Service 模板: `templates/etcd/etcd.service.tmpl`

2. **模板内容**:
   同场景2.1和1.2中的模板内容。

3. **渲染模板**:
   - 使用配置参数渲染所有节点的 kubeadm 配置文件
   - 使用节点特定参数渲染 etcd service 文件

4. **分发配置**:
   - 将渲染后的配置文件分发到相应节点

5. **启动服务**:
   - 在所有 Etcd 节点启动 etcd 服务并组建集群
   - 在第一台 Master 节点执行 kubeadm 初始化
   - 在其他节点执行相应的 kubeadm join 命令

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

#### 2.3.4 场景 Kubernetes=kubeadm, Etcd=exist
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = exist`
- `spec.etcd.external_endpoints` 必须配置
- `spec.loadbalancer.enabled = false`

**部署步骤**:

1. **模板文件**:
   - Kubeadm 配置模板（同场景2.1）
   - Kubelet Service 模板: `templates/kubernetes/binary/kubelet/kubelet.service.tmpl`

2. **模板内容**:
   同场景2.1中的模板内容。

3. **渲染模板**:
   - 使用配置参数渲染所有节点的 kubeadm 配置文件，其中包含外部 etcd 的配置
   - 使用节点特定参数渲染 kubelet service 文件

4. **分发配置**:
   - 将渲染后的配置文件分发到相应节点

5. **启动服务**:
   - 在第一台 Master 节点执行 kubeadm 初始化
   - 获取 join token 和 certificate key
   - 在其他 Master 节点执行 kubeadm join（控制平面）
   - 在 Worker 节点执行 kubeadm join

6. **部署网络插件**:
   - 部署 Calico 或其他 CNI 网络插件

### 2.4 场景3: 多Master集群，LoadBalancer启用，Internal模式

#### 2.4.1 场景3.1: LoadBalancer=internal, Type=haproxy, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = haproxy`

**部署步骤**:

1. **模板文件**:
   - HAProxy Static Pod 模板: `templates/loadbalancer/static-pod/haproxy-pod.yaml.tmpl`
   - HAProxy 配置模板: `templates/loadbalancer/static-pod/haproxy.cfg.tmpl`

2. **模板内容**:

   **HAProxy Static Pod 模板内容** (`templates/loadbalancer/static-pod/haproxy-pod.yaml.tmpl`):
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: haproxy-lb
     namespace: kube-system
     labels:
       addonmanager.kubernetes.io/mode: Reconcile
       k8s-app: kube-haproxy
     annotations:
       # 这里的 checksum 可以随便改，或者去掉，通常由工具生成
       cfg-checksum: "haproxy-config-v1"
   spec:
     hostNetwork: true
     dnsPolicy: ClusterFirstWithHostNet
     nodeSelector:
       kubernetes.io/os: linux
     priorityClassName: system-node-critical
     containers:
     - name: haproxy
       # 请确保你的环境中能拉取到 haproxy 镜像，离线环境请替换为私有仓库地址
       image: haproxy:2.8
       imagePullPolicy: IfNotPresent
       resources:
         requests:
           cpu: 25m
           memory: 32M
       livenessProbe:
         httpGet:
           path: /healthz
           port: 8081
       readinessProbe:
         httpGet:
           path: /healthz
           port: 8081
       volumeMounts:
       - mountPath: /usr/local/etc/haproxy/
         name: etc-haproxy
         readOnly: true
     volumes:
     - name: etc-haproxy
       hostPath:
         path: /etc/kubekey/haproxy
   ```

   **HAProxy 配置模板内容** (`templates/loadbalancer/static-pod/haproxy.cfg.tmpl`):
   ```
   global
       maxconn                 4000
       log                     127.0.0.1 local0

   defaults
       mode                    http
       log                     global
       option                  httplog
       option                  dontlognull
       option                  http-server-close
       option                  redispatch
       retries                 5
       timeout http-request    5m
       timeout queue           5m
       timeout connect         30s
       timeout client          30s
       timeout server          15m
       timeout http-keep-alive 30s
       timeout check           30s
       maxconn                 4000

   frontend healthz
     bind *:8081
     mode http
     monitor-uri /healthz

   frontend kube_api_frontend
     bind 127.0.0.1:6443
     mode tcp
     option tcplog
     default_backend kube_api_backend

   backend kube_api_backend
     mode tcp
     balance leastconn
     default-server inter 15s downinter 15s rise 2 fall 2 slowstart 60s maxconn 1000 maxqueue 256 weight 100
     option httpchk GET /healthz
     http-check expect status 200
   {{- range .BackendServers }}
     server {{ .Name }} {{ .Address }} check check-ssl verify none
   {{- end }}
   ```

3. **渲染模板**:
   - 使用 Master 节点信息渲染 HAProxy 配置
   - 使用配置参数渲染 HAProxy Static Pod 文件

4. **分发配置**:
   - 将渲染后的 HAProxy 配置和 Static Pod 文件分发到 Worker 节点的 `/etc/kubernetes/manifests/` 目录

5. **其余步骤**:
   - 执行与场景2.1相同的集群初始化和节点加入步骤

#### 2.4.2 场景3.2: LoadBalancer=internal, Type=haproxy, Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = haproxy`

**部署步骤**:
与场景3.1类似，但在部署 Etcd 时使用二进制方式。

#### 2.4.3 场景3.3: LoadBalancer=internal, Type=haproxy, Kubernetes=kubexm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubexm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = haproxy`

**部署步骤**:

1. **模板文件**:
   - HAProxy Service 模板: `templates/loadbalancer/haproxy.service.tmpl`
   - HAProxy 配置模板: `templates/loadbalancer/haproxy.cfg.tmpl`

2. **模板内容**:

   **HAProxy Service 模板内容** (`templates/loadbalancer/haproxy.service.tmpl`):
   ```ini
   [Unit]
   Description=HAProxy Load Balancer
   After=network.target

   [Service]
   ExecStart=/usr/local/sbin/haproxy -f /etc/haproxy/haproxy.cfg
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```

3. **渲染模板**:
   - 使用 Master 节点信息渲染 HAProxy 配置
   - 使用配置参数渲染 HAProxy Service 文件

4. **分发配置**:
   - 将渲染后的 HAProxy 配置和服务文件分发到 Worker 节点

5. **启动服务**:
   - 在 Worker 节点启动 HAProxy 服务
   - 执行与场景2.2相同的集群部署步骤

#### 2.4.4 场景3.4: LoadBalancer=internal, Type=nginx, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = nginx`

**部署步骤**:

1. **模板文件**:
   - Nginx Static Pod 模板: `templates/loadbalancer/static-pod/nginx-pod.yaml.tmpl`
   - Nginx 配置模板: `templates/loadbalancer/static-pod/nginx.conf.tmpl`

2. **模板内容**:

   **Nginx Static Pod 模板内容** (`templates/loadbalancer/static-pod/nginx-pod.yaml.tmpl`):
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: nginx-lb
     namespace: kube-system
     labels:
       addonmanager.kubernetes.io/mode: Reconcile
       k8s-app: kube-nginx
     annotations:
       # 这里的 checksum 可以随便改，或者去掉，通常由工具生成
       cfg-checksum: "nginx-config-v1"
   spec:
     hostNetwork: true
     dnsPolicy: ClusterFirstWithHostNet
     nodeSelector:
       kubernetes.io/os: linux
     priorityClassName: system-node-critical
     containers:
     - name: nginx
       # 请确保你的环境中能拉取到 nginx 镜像，离线环境请替换为私有仓库地址
       image: nginx:1.25
       imagePullPolicy: IfNotPresent
       resources:
         requests:
           cpu: 25m
           memory: 32M
       livenessProbe:
         httpGet:
           path: /healthz
           port: 8081
         initialDelaySeconds: 10
         periodSeconds: 10
       readinessProbe:
         httpGet:
           path: /healthz
           port: 8081
       volumeMounts:
       # 注意：这里直接挂载文件到 /etc/nginx/nginx.conf
       - mountPath: /etc/nginx/nginx.conf
         name: etc-nginx
         readOnly: true
         subPath: nginx.conf # 使用 subPath 挂载单个文件
     volumes:
     - name: etc-nginx
       hostPath:
         # 指向宿主机配置文件目录
         path: /etc/kubekey/nginx
         type: Directory
   ```

   **Nginx 配置模板内容** (`templates/loadbalancer/static-pod/nginx.conf.tmpl`):
   ```
   user  nginx;
   worker_processes  auto;
   error_log  /var/log/nginx/error.log notice;
   pid        /var/run/nginx.pid;

   events {
       worker_connections  4096;  # 对应 HAProxy 的 maxconn
   }

   # 1. TCP 负载均衡 (对应 HAProxy 的 kube_api_frontend/backend)
   stream {
       upstream kube_apiserver {
           least_conn; # 对应 HAProxy 的 balance leastconn

           # 后端服务器列表
       {{- range .UpstreamServers }}
           server {{ .Address }};
       {{- end }}
       }

       server {
           # 监听本地 6443，对应 HAProxy 的 bind 127.0.0.1:6443
           listen        127.0.0.1:6443;
           proxy_pass    kube_apiserver;
           proxy_timeout 10m;
           proxy_connect_timeout 1s;
       }
   }

   # 2. 本地健康检查接口 (对应 HAProxy 的 frontend healthz)
   http {
       server {
           listen 8081; # 监听 8081

           location /healthz {
               access_log off;
               return 200 'OK'; # 直接返回 200
               add_header Content-Type text/plain;
           }
       }
   }
   ```

3. **渲染模板**:
   - 使用 Master 节点信息渲染 Nginx 配置
   - 使用配置参数渲染 Nginx Static Pod 文件

4. **分发配置**:
   - 将渲染后的 Nginx 配置和 Static Pod 文件分发到 Worker 节点的 `/etc/kubernetes/manifests/` 目录

5. **其余步骤**:
   - 执行与场景2.1相同的集群初始化和节点加入步骤

#### 2.4.5 场景3.5: LoadBalancer=internal, Type=nginx, Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = nginx`

**部署步骤**:
与场景3.4类似，但在部署 Etcd 时使用二进制方式。

#### 2.4.6 场景3.6: LoadBalancer=internal, Type=nginx, Kubernetes=kubexm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubexm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = nginx`

**部署步骤**:

1. **模板文件**:
   - Nginx Service 模板: `templates/loadbalancer/nginx.service.tmpl`
   - Nginx 配置模板: `templates/loadbalancer/nginx.conf.tmpl`

2. **模板内容**:

   **Nginx Service 模板内容** (`templates/loadbalancer/nginx.service.tmpl`):
   ```ini
   [Unit]
   Description=The NGINX HTTP and reverse proxy server
   After=network.target remote-fs.target nss-lookup.target

   [Service]
   Type=forking
   PIDFile=/var/run/nginx.pid
   ExecStartPre=/usr/sbin/nginx -t
   ExecStart=/usr/sbin/nginx
   ExecReload=/bin/kill -s HUP $MAINPID
   KillSignal=SIGQUIT
   TimeoutStopSec=5
   KillMode=process
   PrivateTmp=true

   [Install]
   WantedBy=multi-user.target
   ```

3. **渲染模板**:
   - 使用 Master 节点信息渲染 Nginx 配置
   - 使用配置参数渲染 Nginx Service 文件

4. **分发配置**:
   - 将渲染后的 Nginx 配置和服务文件分发到 Worker 节点

5. **启动服务**:
   - 在 Worker 节点启动 Nginx 服务
   - 执行与场景2.2相同的集群部署步骤

#### 2.4.7 场景3.7: LoadBalancer=internal, Type=exist, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = internal`
- `spec.loadbalancer.type = exist`

**部署步骤**:
1. **前提条件**:
   - 已存在可用的负载均衡器实例
   - 负载均衡器已正确配置并指向所有 Master 节点的 API Server 端口

2. **部署步骤**:
   - 跳过负载均衡器组件的安装和配置
   - 执行与场景2.1相同的集群初始化和节点加入步骤
### 2.5 场景4: 多Master集群，LoadBalancer启用，Kube-VIP模式

#### 2.5.1 场景4.1: LoadBalancer=kube-vip, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = kube-vip`

**部署步骤**:

1. **模板文件**:
   - Kube-VIP Static Pod 模板: `templates/loadbalancer/static-pod/kube-vip-pod.yaml.tmpl`

2. **模板内容**:

   **Kube-VIP Static Pod 模板内容** (`templates/loadbalancer/static-pod/kube-vip-pod.yaml.tmpl`):
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     creationTimestamp: null
     name: kube-vip
     namespace: kube-system
   spec:
     containers:
     - args:
       - manager
       env:
       - name: vip_arp
         value: "true"
       - name: port
         value: "6443"
       - name: vip_interface
         value: "{{ .VipInterface }}"
       - name: vip_cidr
         value: "32"
       - name: cp_enable
         value: "true"
       - name: cp_namespace
         value: "kube-system"
       - name: vip_ddns
         value: "false"
       - name: svc_enable
         value: "true"
       - name: vip_leaderelection
         value: "true"
       - name: vip_leaseduration
         value: "5"
       - name: vip_renewdeadline
         value: "3"
       - name: vip_retryperiod
         value: "1"
       - name: address
         value: "{{ .VipAddress }}"
       image: ghcr.io/kube-vip/kube-vip:v0.5.0
       imagePullPolicy: IfNotPresent
       name: kube-vip
       resources: {}
       securityContext:
         capabilities:
           add:
           - NET_ADMIN
           - NET_RAW
       volumeMounts:
       - mountPath: /etc/kubernetes/admin.conf
         name: kubeconfig
     hostNetwork: true
     volumes:
     - hostPath:
         path: /etc/kubernetes/admin.conf
       name: kubeconfig
   status: {}
   ```

3. **渲染模板**:
   - 使用配置参数渲染 Kube-VIP Static Pod 文件

4. **分发配置**:
   - 将渲染后的 Kube-VIP Static Pod 文件分发到 Master 节点的 `/etc/kubernetes/manifests/` 目录

5. **其余步骤**:
   - 执行与场景2.1相同的集群初始化和节点加入步骤

#### 2.5.2 场景4.2: LoadBalancer=kube-vip, Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = kube-vip`

**部署步骤**:
与场景4.1类似，但在部署 Etcd 时使用二进制方式。

#### 2.5.3 场景4.3: LoadBalancer=kube-vip, Kubernetes=kubexm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubexm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = kube-vip`

**部署步骤**:
与场景4.1类似，但使用 kubexm 方式部署 Kubernetes 组件。

#### 2.5.4 场景4.4: LoadBalancer=kube-vip, Kubernetes=kubeadm, Etcd=exist
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = exist`
- `spec.etcd.external_endpoints` 必须配置
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = kube-vip`

**部署步骤**:
与场景4.1类似，但使用外部 Etcd 实例。

### 2.6 场景5: 多Master集群，LoadBalancer启用，External模式

#### 2.6.1 场景5.1: LoadBalancer=external, Type=kubexm-kh, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = kubexm-kh`

**部署步骤**:

1. **模板文件**:
   - Keepalived 配置模板: `templates/loadbalancer/keepalived.conf.tmpl`
   - HAProxy Service 模板: `templates/loadbalancer/haproxy.service.tmpl`
   - HAProxy 配置模板: `templates/loadbalancer/haproxy.cfg.tmpl`

2. **模板内容**:

   **Keepalived 配置模板内容** (`templates/loadbalancer/keepalived.conf.tmpl`):
   ```
   global_defs {
     router_id LVS_DEVEL
     vrrp_version 3
   }

   vrrp_script chk_haproxy {
     script "/etc/keepalived/check_haproxy.sh"
     interval 2
     weight -5
     fall 3
     rise 2
   }

   vrrp_instance VI_1 {
     state {{ .InitialState }}
     interface {{ .Interface }}
     virtual_router_id {{ .VirtualRouterId }}
     priority {{ .Priority }}
     advert_int 1
     authentication {
       auth_type PASS
       auth_pass {{ .AuthPass }}
     }
     virtual_ipaddress {
       {{ .VipAddress }}/24
     }
     track_script {
       chk_haproxy
     }
   }
   ```

   **HAProxy Service 模板内容** (已在场景2.4.3中提供)

   **HAProxy 配置模板内容** (已在场景2.4.1中提供)

3. **渲染模板**:
   - 使用配置参数渲染 Keepalived 和 HAProxy 的配置及服务文件

4. **分发配置**:
   - 将渲染后的配置和服务文件分发到 LoadBalancer 节点

5. **启动服务**:
   - 在 LoadBalancer 节点启动 Keepalived 和 HAProxy 服务

6. **其余步骤**:
   - 执行与场景2.1相同的集群初始化和节点加入步骤

#### 2.6.2 场景5.2: LoadBalancer=external, Type=kubexm-kn, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = kubexm-kn`

**部署步骤**:

1. **模板文件**:
   - Keepalived 配置模板: `templates/loadbalancer/keepalived.conf.tmpl`
   - Nginx Service 模板: `templates/loadbalancer/nginx.service.tmpl`
   - Nginx 配置模板: `templates/loadbalancer/nginx.conf.tmpl`

2. **模板内容**:

   **Keepalived 配置模板内容** (已在场景5.1中提供)

   **Nginx Service 模板内容** (已在场景2.4.6中提供)

   **Nginx 配置模板内容** (已在场景2.4.4中提供)

3. **渲染模板**:
   - 使用配置参数渲染 Keepalived 和 Nginx 的配置及服务文件

4. **分发配置**:
   - 将渲染后的配置和服务文件分发到 LoadBalancer 节点

5. **启动服务**:
   - 在 LoadBalancer 节点启动 Keepalived 和 Nginx 服务

6. **其余步骤**:
   - 执行与场景2.1相同的集群初始化和节点加入步骤

#### 2.6.3 场景5.3: LoadBalancer=external, Type=exist, Kubernetes=kubeadm, Etcd=kubeadm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubeadm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = exist`

**部署步骤**:

1. **前提条件**:
   - 已存在可用的外部负载均衡器实例
   - 负载均衡器已正确配置并指向所有 Master 节点的 API Server 端口

2. **部署步骤**:
   - 跳过负载均衡器组件的安装和配置
   - 执行与场景2.1相同的集群初始化和节点加入步骤

#### 2.6.4 场景5.4: LoadBalancer=external, Type=kubexm-kh, Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = kubexm-kh`

**部署步骤**:
与场景5.1类似，但在部署 Etcd 时使用二进制方式。

#### 2.6.5 场景5.5: LoadBalancer=external, Type=kubexm-kn, Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = kubexm-kn`

**部署步骤**:
与场景5.2类似，但在部署 Etcd 时使用二进制方式。

#### 2.6.6 场景5.6: LoadBalancer=external, Type=exist, Kubernetes=kubeadm, Etcd=kubexm
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = kubexm`
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = exist`

**部署步骤**:
与场景5.3类似，但在部署 Etcd 时使用二进制方式。

#### 2.6.7 场景5.7: LoadBalancer=external, Type=kubexm-kh, Kubernetes=kubeadm, Etcd=exist
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = exist`
- `spec.etcd.external_endpoints` 必须配置
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = kubexm-kh`

**部署步骤**:
与场景5.1类似，但使用外部 Etcd 实例。

#### 2.6.8 场景5.8: LoadBalancer=external, Type=kubexm-kn, Kubernetes=kubeadm, Etcd=exist
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = exist`
- `spec.etcd.external_endpoints` 必须配置
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = kubexm-kn`

**部署步骤**:
与场景5.2类似，但使用外部 Etcd 实例。

#### 2.6.9 场景5.9: LoadBalancer=external, Type=exist, Kubernetes=kubeadm, Etcd=exist
**配置要求**:
- `spec.kubernetes.type = kubeadm`
- `spec.etcd.type = exist`
- `spec.etcd.external_endpoints` 必须配置
- `spec.loadbalancer.enabled = true`
- `spec.loadbalancer.mode = external`
- `spec.loadbalancer.type = exist`

**部署步骤**:
与场景5.3类似，但使用外部 Etcd 实例。

## 3. 总结

以上文档详细描述了 KubeXM 支持的多种 Kubernetes 集群部署场景的具体流程。每种场景都有其特定的配置要求、模板文件、渲染方式、分发策略和启动步骤。通过遵循这些步骤，可以成功部署符合要求的 Kubernetes 集群。

需要注意的是：
1. Etcd 类型分为 `kubexm`、`kubeadm` 和 `exist` 三种
2. LoadBalancer 类型分为 `haproxy`、`nginx`、`kubexm-kh`、`kubexm-kn` 和 `exist` 几种
3. 所有模板文件均来自 `step.md` 中提供的实际内容
4. 每个场景都包含了完整的部署步骤和配置说明