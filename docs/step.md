部署kubernetes流程

# 前置工作

## 配置文件
### 机器清单文件
```
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
    autoRenewCerts: true              # 自动续期kubernetes叶子结
    # dns_service_ip: 10.96.0.10      # DNS Service IP，这个不需要配置，代码自动计算，如果启用了nodelocaldns

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
### 参数配置文件说明
本文档详细描述 Cluster 对象中各字段的生效逻辑、默认值处理以及不同配置组合下的行为差异。

#### 1. 全局部署模式 (spec.mode)
该字段决定集群资源的获取方式，对 Registry 配置有强依赖。
- **online (在线模式)**
  - **行为**：安装程序尝试连接互联网，从 registry.mirrors 中定义的上游仓库（如 Docker Hub, Aliyun）拉取镜像。
  - **依赖**：registry.enable 默认为 false。
  - **异常处理**：若节点无法联网，部署将失败。
- **offline (离线模式)**
  - **行为**：安装程序完全不连接公网。
  - **依赖**：
    - **强依赖**：要求 registry.enable 必须为 true。
    - **强依赖**：此时要求spec.hosts.roleGroups.registry必须配置机器列表，此时安装程序会在registry组节点启动一个部署reigstry仓库
    - 离线模式下需要将registry二进制文件下载到kubexm/packages/registry/${registry_version}/${arch}目录下
      - registry.service模板
        模板放置在kubexm/templates/registry/registry.service.tmpl, 程序自动读取模板渲染出针对特定节点的配置放置在kubexm/packages/${node_name}/registry.service
        ```
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
      - registry配置模板
      模板放置在kubexm/templates/registry/registry.config.tmpl, 程序自动读取模板渲染出针对特定节点的配置放置在kubexm/packages/${node_name}/config.yml
        ```
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
      - 部署registry时
        - 从kubexm/packages/registry/${registry_version}/${arch}/复制registry二进制文件到registry组下的节点的/usr/local/bin/registry
        - 从kubexm/packages/${node_name}/registry.service复制到registry组下的节点的/etc/systemd/system/registry.service
        - 从kubexm/packages/${node_name}/config.yml复制到registry组下的节点的/etc/registry/config.yml
        - 执行systemctl daemon-reload
        - 执行systemctl enable registry
        - 执行systemctl start registry
        - 检测registry是否存活，存活则进行下一步，否则停止

#### 2. Kubernetes 部署类型 (spec.kubernetes.type)
该字段决定了控制平面组件（APIServer, CM, Scheduler）以及**Internal 模式负载均衡器**的运行形态。
- **kubeadm (容器化/标准版)**
  - **组件形态**：APIServer、Scheduler、Controller-Manager等核心组件以 **Static Pod**（静态 Pod）形式运行，配置文件由 Kubelet 管理（/etc/kubernetes/manifests）。

  ```
  # 首台master的kubeadm-config.yaml
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

  ```
  ---
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: JoinConfiguration
  discovery:
    bootstrapToken:
      apiServerEndpoint: lb.kubesphere.local:6443
      token: "66f0j7.wp1rfhds94mh95hm"
      unsafeSkipCAVerification: true
    tlsBootstrapToken: "66f0j7.wp1rfhds94mh95hm"
  controlPlane:
    localAPIEndpoint:
      advertiseAddress: 172.30.1.14
      bindPort: 6443
    certificateKey: 3e1379eeb41a84fd6a8445bb2b29207b3a137ad6fad5ff5db178cb5cf3597d8a
  nodeRegistration:
    criSocket: unix:///run/containerd/containerd.sock
    kubeletExtraArgs:
      cgroup-driver: systemd

  ```

  ```
  ---
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: JoinConfiguration
  discovery:
    bootstrapToken:
      apiServerEndpoint: lb.kubesphere.local:6443
      token: "66f0j7.wp1rfhds94mh95hm"
      unsafeSkipCAVerification: true
    tlsBootstrapToken: "66f0j7.wp1rfhds94mh95hm"
  nodeRegistration:
    criSocket: unix:///run/containerd/containerd.sock
    kubeletExtraArgs:
      cgroup-driver: systemd

  ```

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
  root@node5:~#

  ```

  ```
  apiVersion: v1
  kind: Pod
  metadata:
    annotations:
      kubeadm.kubernetes.io/kube-apiserver.advertise-address.endpoint: 172.30.1.12:6443
    creationTimestamp: null
    labels:
      component: kube-apiserver
      tier: control-plane
    name: kube-apiserver
    namespace: kube-system
  spec:
    containers:
    - command:
      - kube-apiserver
      - --oidc-issuer-url=https://keycloak.kmpp.io/auth/realms/cars
      - --oidc-client-id=kubernetes
      - --oidc-username-claim=preferred_username
      - --oidc-username-prefix=-
      - --oidc-groups-claim=groups
      - --oidc-ca-file=/etc/kubernetes/pki/keycloak.crt
      - --advertise-address=172.30.1.12
      - --allow-privileged=true
      - --audit-log-maxage=30
      - --audit-log-maxbackup=10
      - --audit-log-maxsize=100
      - --authorization-mode=Node,RBAC
      - --bind-address=0.0.0.0
      - --client-ca-file=/etc/kubernetes/pki/ca.crt
      - --enable-admission-plugins=NodeRestriction
      - --enable-bootstrap-token-auth=true
      - --etcd-cafile=/etc/ssl/etcd/ssl/ca.pem
      - --etcd-certfile=/etc/ssl/etcd/ssl/node-node2.pem
      - --etcd-keyfile=/etc/ssl/etcd/ssl/node-node2-key.pem
      - --etcd-servers=https://172.30.1.12:2379,https://172.30.1.14:2379,https://172.30.1.15:2379
      - --feature-gates=RotateKubeletServerCertificate=true,ExpandCSIVolumes=true,CSIStorageCapacity=true
      - --kubelet-client-certificate=/etc/kubernetes/pki/apiserver-kubelet-client.crt
      - --kubelet-client-key=/etc/kubernetes/pki/apiserver-kubelet-client.key
      - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
      - --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
      - --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
      - --requestheader-allowed-names=front-proxy-client
      - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
      - --requestheader-extra-headers-prefix=X-Remote-Extra-
      - --requestheader-group-headers=X-Remote-Group
      - --requestheader-username-headers=X-Remote-User
      - --secure-port=6443
      - --service-account-issuer=https://kubernetes.default.svc.cluster.local
      - --service-account-key-file=/etc/kubernetes/pki/sa.pub
      - --service-account-signing-key-file=/etc/kubernetes/pki/sa.key
      - --service-cluster-ip-range=10.233.0.0/18
      - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
      - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
      image: dockerhub.kubekey.local/kubesphereio/kube-apiserver:v1.24.9
      imagePullPolicy: IfNotPresent
      livenessProbe:
        failureThreshold: 8
        httpGet:
          host: 172.30.1.12
          path: /livez
          port: 6443
          scheme: HTTPS
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 15
      name: kube-apiserver
      readinessProbe:
        failureThreshold: 3
        httpGet:
          host: 172.30.1.12
          path: /readyz
          port: 6443
          scheme: HTTPS
        periodSeconds: 1
        timeoutSeconds: 15
      resources:
        requests:
          cpu: 250m
      startupProbe:
        failureThreshold: 24
        httpGet:
          host: 172.30.1.12
          path: /livez
          port: 6443
          scheme: HTTPS
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 15
      volumeMounts:
      - mountPath: /etc/ssl/certs
        name: ca-certs
        readOnly: true
      - mountPath: /etc/ca-certificates
        name: etc-ca-certificates
        readOnly: true
      - mountPath: /etc/pki
        name: etc-pki
        readOnly: true
      - mountPath: /etc/ssl/etcd/ssl
        name: etcd-certs-0
        readOnly: true
      - mountPath: /etc/kubernetes/pki
        name: k8s-certs
        readOnly: true
      - mountPath: /usr/local/share/ca-certificates
        name: usr-local-share-ca-certificates
        readOnly: true
      - mountPath: /usr/share/ca-certificates
        name: usr-share-ca-certificates
        readOnly: true
    hostNetwork: true
    priorityClassName: system-node-critical
    securityContext:
      seccompProfile:
        type: RuntimeDefault
    volumes:
    - hostPath:
        path: /etc/ssl/certs
        type: DirectoryOrCreate
      name: ca-certs
    - hostPath:
        path: /etc/ca-certificates
        type: DirectoryOrCreate
      name: etc-ca-certificates
    - hostPath:
        path: /etc/pki
        type: DirectoryOrCreate
      name: etc-pki
    - hostPath:
        path: /etc/ssl/etcd/ssl
        type: DirectoryOrCreate
      name: etcd-certs-0
    - hostPath:
        path: /etc/kubernetes/pki
        type: DirectoryOrCreate
      name: k8s-certs
    - hostPath:
        path: /usr/local/share/ca-certificates
        type: DirectoryOrCreate
      name: usr-local-share-ca-certificates
    - hostPath:
        path: /usr/share/ca-certificates
        type: DirectoryOrCreate
      name: usr-share-ca-certificates
  status: {}
  ```

  ```
  apiVersion: v1
  kind: Pod
  metadata:
    creationTimestamp: null
    labels:
      component: kube-controller-manager
      tier: control-plane
    name: kube-controller-manager
    namespace: kube-system
  spec:
    containers:
    - command:
      - kube-controller-manager
      - --allocate-node-cidrs=true
      - --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
      - --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
      - --bind-address=0.0.0.0
      - --client-ca-file=/etc/kubernetes/pki/ca.crt
      - --cluster-cidr=10.233.64.0/18
      - --cluster-name=cluster.local
      - --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
      - --cluster-signing-duration=87600h
      - --cluster-signing-key-file=/etc/kubernetes/pki/ca.key
      - --controllers=*,bootstrapsigner,tokencleaner
      - --feature-gates=RotateKubeletServerCertificate=true,ExpandCSIVolumes=true,CSIStorageCapacity=true
      - --kubeconfig=/etc/kubernetes/controller-manager.conf
      - --leader-elect=true
      - --node-cidr-mask-size=24
      - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
      - --root-ca-file=/etc/kubernetes/pki/ca.crt
      - --service-account-private-key-file=/etc/kubernetes/pki/sa.key
      - --service-cluster-ip-range=10.233.0.0/18
      - --use-service-account-credentials=true
      image: dockerhub.kubekey.local/kubesphereio/kube-controller-manager:v1.24.9
      imagePullPolicy: IfNotPresent
      livenessProbe:
        failureThreshold: 8
        httpGet:
          path: /healthz
          port: 10257
          scheme: HTTPS
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 15
      name: kube-controller-manager
      resources:
        requests:
          cpu: 200m
      startupProbe:
        failureThreshold: 24
        httpGet:
          path: /healthz
          port: 10257
          scheme: HTTPS
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 15
      volumeMounts:
      - mountPath: /etc/ssl/certs
        name: ca-certs
        readOnly: true
      - mountPath: /etc/ca-certificates
        name: etc-ca-certificates
        readOnly: true
      - mountPath: /etc/pki
        name: etc-pki
        readOnly: true
      - mountPath: /usr/libexec/kubernetes/kubelet-plugins/volume/exec
        name: flexvolume-dir
      - mountPath: /etc/localtime
        name: host-time
        readOnly: true
      - mountPath: /etc/kubernetes/pki
        name: k8s-certs
        readOnly: true
      - mountPath: /etc/kubernetes/controller-manager.conf
        name: kubeconfig
        readOnly: true
      - mountPath: /usr/local/share/ca-certificates
        name: usr-local-share-ca-certificates
        readOnly: true
      - mountPath: /usr/share/ca-certificates
        name: usr-share-ca-certificates
        readOnly: true
    hostNetwork: true
    priorityClassName: system-node-critical
    securityContext:
      seccompProfile:
        type: RuntimeDefault
    volumes:
    - hostPath:
        path: /etc/ssl/certs
        type: DirectoryOrCreate
      name: ca-certs
    - hostPath:
        path: /etc/ca-certificates
        type: DirectoryOrCreate
      name: etc-ca-certificates
    - hostPath:
        path: /etc/pki
        type: DirectoryOrCreate
      name: etc-pki
    - hostPath:
        path: /usr/libexec/kubernetes/kubelet-plugins/volume/exec
        type: DirectoryOrCreate
      name: flexvolume-dir
    - hostPath:
        path: /etc/localtime
        type: ""
      name: host-time
    - hostPath:
        path: /etc/kubernetes/pki
        type: DirectoryOrCreate
      name: k8s-certs
    - hostPath:
        path: /etc/kubernetes/controller-manager.conf
        type: FileOrCreate
      name: kubeconfig
    - hostPath:
        path: /usr/local/share/ca-certificates
        type: DirectoryOrCreate
      name: usr-local-share-ca-certificates
    - hostPath:
        path: /usr/share/ca-certificates
        type: DirectoryOrCreate
      name: usr-share-ca-certificates
  status: {}

  ```

  ```
  apiVersion: v1
  kind: Pod
  metadata:
    creationTimestamp: null
    labels:
      component: kube-scheduler
      tier: control-plane
    name: kube-scheduler
    namespace: kube-system
  spec:
    containers:
    - command:
      - kube-scheduler
      - --authentication-kubeconfig=/etc/kubernetes/scheduler.conf
      - --authorization-kubeconfig=/etc/kubernetes/scheduler.conf
      - --bind-address=0.0.0.0
      - --feature-gates=RotateKubeletServerCertificate=true,ExpandCSIVolumes=true,CSIStorageCapacity=true
      - --kubeconfig=/etc/kubernetes/scheduler.conf
      - --leader-elect=true
      - --v=10
      image: dockerhub.kubekey.local/kubesphereio/kube-scheduler:v1.24.9
      imagePullPolicy: IfNotPresent
      livenessProbe:
        failureThreshold: 8
        httpGet:
          path: /healthz
          port: 10259
          scheme: HTTPS
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 15
      name: kube-scheduler
      resources:
        requests:
          cpu: 100m
      startupProbe:
        failureThreshold: 24
        httpGet:
          path: /healthz
          port: 10259
          scheme: HTTPS
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 15
      volumeMounts:
      - mountPath: /etc/kubernetes/scheduler.conf
        name: kubeconfig
        readOnly: true
    hostNetwork: true
    priorityClassName: system-node-critical
    securityContext:
      seccompProfile:
        type: RuntimeDefault
    volumes:
    - hostPath:
        path: /etc/kubernetes/scheduler.conf
        type: FileOrCreate
      name: kubeconfig
  status: {}

  ```


  ```
  apiVersion: v1
  kind: Pod
  metadata:
    name: haproxy
    namespace: kube-system
    labels:
      addonmanager.kubernetes.io/mode: Reconcile
      k8s-app: kube-haproxy
    annotations:
      cfg-checksum: "87db2befee076eda446cce1e9fc76f53"
  spec:
    hostNetwork: true
    dnsPolicy: ClusterFirstWithHostNet
    nodeSelector:
      kubernetes.io/os: linux
    priorityClassName: system-node-critical
    containers:
    - name: haproxy
      image: dockerhub.kubekey.local/kubesphereio/haproxy:2.3
      imagePullPolicy: Always
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
    server node2 172.30.1.12:6443 check check-ssl verify none
    server node3 172.30.1.14:6443 check check-ssl verify none
    server node4 172.30.1.15:6443 check check-ssl verify none
  ```

  ```
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
          server 172.30.1.12:6443;
          server 172.30.1.14:6443;
          server 172.30.1.15:6443;
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

  ```
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
  root@node2:~#

  ```

  ```
  ExecStart=/usr/local/bin/etcd
  NotifyAccess=all
  RestartSec=10s
  LimitNOFILE=40000
  Restart=always

  [Install]
  WantedBy=multi-user.target
  root@node2:~# cat /etc/etcd.env
  # Environment file for etcd v3.4.13
  ETCD_DATA_DIR=/var/lib/etcd
  ETCD_ADVERTISE_CLIENT_URLS=https://172.30.1.12:2379
  ETCD_INITIAL_ADVERTISE_PEER_URLS=https://172.30.1.12:2380
  ETCD_INITIAL_CLUSTER_STATE=existing
  ETCD_METRICS=basic
  ETCD_LISTEN_CLIENT_URLS=https://172.30.1.12:2379,https://127.0.0.1:2379
  ETCD_ELECTION_TIMEOUT=5000
  ETCD_HEARTBEAT_INTERVAL=250
  ETCD_INITIAL_CLUSTER_TOKEN=k8s_etcd
  ETCD_LISTEN_PEER_URLS=https://172.30.1.12:2380
  ETCD_NAME=etcd-node2
  ETCD_PROXY=off
  ETCD_ENABLE_V2=true
  ETCD_INITIAL_CLUSTER=etcd-node2=https://172.30.1.12:2380,etcd-node3=https://172.30.1.14:2380,etcd-node4=https://172.30.1.15:2380
  ETCD_AUTO_COMPACTION_RETENTION=8
  ETCD_SNAPSHOT_COUNT=10000

  # TLS settings
  ETCD_TRUSTED_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
  ETCD_CERT_FILE=/etc/ssl/etcd/ssl/member-node2.pem
  ETCD_KEY_FILE=/etc/ssl/etcd/ssl/member-node2-key.pem
  ETCD_CLIENT_CERT_AUTH=true

  ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
  ETCD_PEER_CERT_FILE=/etc/ssl/etcd/ssl/member-node2.pem
  ETCD_PEER_KEY_FILE=/etc/ssl/etcd/ssl/member-node2-key.pem
  ETCD_PEER_CLIENT_CERT_AUTH=True

  # CLI settings
  ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
  ETCDCTL_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
  ETCDCTL_KEY_FILE=/etc/ssl/etcd/ssl/admin-node2-key.pem
  ETCDCTL_CERT_FILE=/etc/ssl/etcd/ssl/admin-node2.pem
  root@node2:~#

  ```

  ```
  root@node2:~# cat /etc/systemd/system/backup-etcd.timer
  [Unit]
  Description=Timer to backup ETCD
  [Timer]
  OnCalendar=*-*-* 02:00:00
  Unit=backup-etcd.service
  [Install]
  WantedBy=multi-user.target

  ```

  ```
  root@node2:~# cat /etc/systemd/system/backup-etcd.timer
  [Unit]
  Description=Timer to backup ETCD
  [Timer]
  OnCalendar=*-*-* 02:00:00
  Unit=backup-etcd.service
  [Install]
  WantedBy=multi-user.target
  root@node2:~# cat /etc/systemd/system/backup-etcd.service
  [Unit]
  Description=Backup ETCD
  [Service]
  Type=oneshot
  ExecStart=/usr/local/bin/kube-scripts/etcd-backup.sh
  root@node2:~#

  ```


  ```
  #!/bin/bash

  set -o errexit
  set -o nounset
  set -o pipefail

  ETCDCTL_PATH='/usr/local/bin/etcdctl'
  ENDPOINTS='https://172.30.1.12:2379'
  ETCD_DATA_DIR="/var/lib/etcd"
  BACKUP_DIR="/var/backups/kube_etcd/etcd-$(date +%Y-%m-%d-%H-%M-%S)"
  KEEPBACKUPNUMBER='6'
  ETCDBACKUPSCIPT='/usr/local/bin/kube-scripts'

  ETCDCTL_CERT="/etc/ssl/etcd/ssl/admin-node2.pem"
  ETCDCTL_KEY="/etc/ssl/etcd/ssl/admin-node2-key.pem"
  ETCDCTL_CA_FILE="/etc/ssl/etcd/ssl/ca.pem"

  [ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR

  export ETCDCTL_API=2;$ETCDCTL_PATH backup --data-dir $ETCD_DATA_DIR --backup-dir $BACKUP_DIR

  sleep 3

  {
  export ETCDCTL_API=3;$ETCDCTL_PATH --endpoints="$ENDPOINTS" snapshot save $BACKUP_DIR/snapshot.db \
                                     --cacert="$ETCDCTL_CA_FILE" \
                                     --cert="$ETCDCTL_CERT" \
                                     --key="$ETCDCTL_KEY"
  } > /dev/null

  sleep 3

  cd $BACKUP_DIR/../ && ls -lt |awk '{if(NR > '$KEEPBACKUPNUMBER'){print "rm -rf "$9}}'|sh

  ```


  ```
  root@node2:~# cat /etc/systemd/system/k8s-certs-renew.timer
  [Unit]
  Description=Timer to renew K8S control plane certificates
  [Timer]
  OnCalendar=Mon *-*-* 03:00:00
  Unit=k8s-certs-renew.service
  [Install]
  WantedBy=multi-user.target

  ```

  ```
  root@node2:~# cat /etc/systemd/system/k8s-certs-renew.service
  [Unit]
  Description=Renew K8S control plane certificates
  [Service]
  Type=oneshot
  ExecStart=/usr/local/bin/kube-scripts/k8s-certs-renew.sh
  root@node2:~#

  ```


  ```
  #!/bin/bash
  kubeadmCerts='/usr/local/bin/kubeadm certs'
  getCertValidDays() {
    local earliestExpireDate; earliestExpireDate=$(${kubeadmCerts} check-expiration | grep -o "[A-Za-z]\{3,4\}\s\w\w,\s[0-9]\{4,\}\s\w*:\w*\s\w*\s*" | xargs -I {} date -d {} +%s | sort | head -n 1)
    local today; today="$(date +%s)"
    echo -n $(( ($earliestExpireDate - $today) / (24 * 60 * 60) ))
  }
  echo "## Expiration before renewal ##"
  ${kubeadmCerts} check-expiration
  if [ $(getCertValidDays) -lt 30 ]; then
    echo "## Renewing certificates managed by kubeadm ##"
    ${kubeadmCerts} renew all
    echo "## Restarting control plane pods managed by kubeadm ##"
    $(which crictl | grep crictl) pods --namespace kube-system --name 'kube-scheduler-*|kube-controller-manager-*|kube-apiserver-*|etcd-*' -q | /usr/bin/xargs $(which crictl | grep crictl) rmp -f
    echo "## Updating /root/.kube/config ##"
    cp /etc/kubernetes/admin.conf /root/.kube/config
  fi
  echo "## Waiting for apiserver to be up again ##"
  until printf "" 2>>/dev/null >>/dev/tcp/127.0.0.1/6443; do sleep 1; done
  echo "## Expiration after renewal ##"
  ${kubeadmCerts} check-expiration

  ```


  - **对 LB 的影响**：若启用 internal 负载均衡，LB 也必须以 **Static Pod** 形式部署。
- **kubexm (二进制版)**
  - **组件形态**：APIServer、Scheduler、Controller-Manager、kube-proxy 等核心组件以 **Systemd Service**（二进制进程）形式运行，配置文件在 /usr/lib/systemd/system/。
  - **对 LB 的影响**：若启用 internal 负载均衡，LB 必须以 **Systemd Service**（二进制进程）形式部署。
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


  ```
  [Unit]
  Description=l4 nginx proxy for kube-apiservers
  After=network.target
  After=network-online.target
  Wants=network-online.target

  [Service]
  Type=forking
  ExecStartPre=/etc/kube-lb/sbin/kube-lb -c /etc/kube-lb/conf/kube-lb.conf -p /etc/kube-lb -t
  ExecStart=/etc/kube-lb/sbin/kube-lb -c /etc/kube-lb/conf/kube-lb.conf -p /etc/kube-lb
  ExecReload=/etc/kube-lb/sbin/kube-lb -c /etc/kube-lb/conf/kube-lb.conf -p /etc/kube-lb -s reload
  PrivateTmp=true
  Restart=always
  RestartSec=15
  StartLimitInterval=0
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
  ```

  ```
  user root;
  worker_processes 1;

  error_log  /etc/kube-lb/logs/error.log warn;

  events {
      worker_connections  3000;
  }

  stream {
      upstream backend {
          server 10.200.200.170:6443    max_fails=2 fail_timeout=3s;
      }

      server {
          listen 127.0.0.1:6443;
          proxy_connect_timeout 1s;
          proxy_pass backend;
      }
  }

  ```

  ```
  # /etc/systemd/system/kube-lb.service

  [Unit]
  Description=HAProxy Load Balancer for Kubernetes API Server
  Documentation=man:haproxy(1)
  After=network-online.target rsyslog.service
  Wants=network-online.target

  [Service]
  Environment="CONFIG=/etc/kube-lb/conf/haproxy.conf"
  Environment="PIDFILE=/var/run/haproxy.pid"
  # 如果你的 haproxy 是自己编译放在特殊目录的，请修改下面这行 /usr/sbin/haproxy
  ExecStartPre=/usr/sbin/haproxy -f /etc/kube-lb/conf/haproxy.cfg -c -q
  ExecStart=/usr/sbin/haproxy -Ws -f /etc/kube-lb/conf/haproxy.cfg -p /var/run/haproxy.pid
  ExecReload=/bin/kill -USR2 $MAINPID
  KillMode=mixed
  Restart=always
  RestartSec=5
  Type=notify
  LimitNOFILE=65536

  [Install]
  WantedBy=multi-user.target
  ```

  ```
  # /etc/kube-lb/conf/haproxy.cfg

  global
      log         127.0.0.1 local2
      # 这里的 pidfile 路径要确保目录存在且有权限
      pidfile     /var/run/haproxy.pid
      maxconn     4000
      user        root   # 为了监听端口和读文件，或者改成 haproxy 用户
      group       root
      daemon

  defaults
      mode                    tcp
      log                     global
      option                  tcplog
      option                  dontlognull
      option                  redispatch
      retries                 3
      timeout queue           1m
      timeout connect         10s
      timeout client          1m
      timeout server          1m
      timeout check           10s
      maxconn                 3000

  # 核心配置部分：对应之前的 stream { ... }
  listen kube-apiserver
      bind 127.0.0.1:6443
      mode tcp
      balance roundrobin

      # 简单的 TCP 检查
      # server <节点名> <IP:Port> check
      server master1 10.200.200.170:6443 check inter 3s fall 3 rise 2

      # 如果有多个 Master，继续往下加，例如：
      # server master2 10.200.200.171:6443 check inter 3s fall 3 rise 2
      # server master3 10.200.200.172:6443 check inter 3s fall 3 rise 2
  ```

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

  ```
  [Unit]
  Description=chrony, an NTP client/server
  Documentation=man:chronyd(8) man:chronyc(1) man:chrony.conf(5)
  Conflicts=openntpd.service ntp.service ntpsec.service
  Wants=time-sync.target
  Before=time-sync.target
  After=network.target

  [Service]
  Type=forking
  PIDFile=/run/chrony/chronyd.pid
  EnvironmentFile=-/etc/default/chrony
  ExecStart=/usr/lib/systemd/scripts/chronyd-starter.sh $DAEMON_OPTS

  CapabilityBoundingSet=~CAP_AUDIT_CONTROL CAP_AUDIT_READ CAP_AUDIT_WRITE
  CapabilityBoundingSet=~CAP_BLOCK_SUSPEND CAP_KILL CAP_LEASE CAP_LINUX_IMMUTABLE
  CapabilityBoundingSet=~CAP_MAC_ADMIN CAP_MAC_OVERRIDE CAP_MKNOD CAP_SYS_ADMIN
  CapabilityBoundingSet=~CAP_SYS_BOOT CAP_SYS_CHROOT CAP_SYS_MODULE CAP_SYS_PACCT
  CapabilityBoundingSet=~CAP_SYS_PTRACE CAP_SYS_RAWIO CAP_SYS_TTY_CONFIG CAP_WAKE_ALARM
  DeviceAllow=char-pps rw
  DeviceAllow=char-ptp rw
  DeviceAllow=char-rtc rw
  DevicePolicy=closed
  LockPersonality=yes
  MemoryDenyWriteExecute=yes
  NoNewPrivileges=yes
  PrivateTmp=yes
  ProcSubset=pid
  ProtectControlGroups=yes
  ProtectHome=yes
  ProtectHostname=yes
  ProtectKernelLogs=yes
  ProtectKernelModules=yes
  ProtectKernelTunables=yes
  ProtectProc=invisible
  ProtectSystem=strict
  ReadWritePaths=/run /var/lib/chrony -/var/log
  RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
  RestrictNamespaces=yes
  RestrictSUIDSGID=yes
  SystemCallArchitectures=native
  SystemCallFilter=~@cpu-emulation @debug @module @mount @obsolete @raw-io @reboot @swap

  # Adjust restrictions for /usr/sbin/sendmail (mailonchange directive)
  NoNewPrivileges=no
  ReadWritePaths=-/var/spool
  RestrictAddressFamilies=AF_NETLINK

  [Install]
  Alias=chronyd.service
  WantedBy=multi-user.target

  ```

  ```
  # Welcome to the chrony configuration file. See chrony.conf(5) for more
  # information about usable directives.

  # Include configuration files found in /etc/chrony/conf.d.
  confdir /etc/chrony/conf.d

  # This will use (up to):
  # - 4 sources from ntp.ubuntu.com which some are ipv6 enabled
  # - 2 sources from 2.ubuntu.pool.ntp.org which is ipv6 enabled as well
  # - 1 source from [01].ubuntu.pool.ntp.org each (ipv4 only atm)
  # This means by default, up to 6 dual-stack and up to 2 additional IPv4-only
  # sources will be used.
  # At the same time it retains some protection against one of the entries being
  # down (compare to just using one of the lines). See (LP: #1754358) for the
  # discussion.
  #
  # About using servers from the NTP Pool Project in general see (LP: #104525).
  # Approved by Ubuntu Technical Board on 2011-02-08.
  # See http://www.pool.ntp.org/join.html for more information.
  #pool ntp.ubuntu.com        iburst maxsources 4
  #pool 0.ubuntu.pool.ntp.org iburst maxsources 1
  #pool 1.ubuntu.pool.ntp.org iburst maxsources 1
  #pool 2.ubuntu.pool.ntp.org iburst maxsources 2

  # Use time sources from DHCP.
  sourcedir /run/chrony-dhcp

  # Use NTP sources found in /etc/chrony/sources.d.
  sourcedir /etc/chrony/sources.d

  # This directive specify the location of the file containing ID/key pairs for
  # NTP authentication.
  keyfile /etc/chrony/chrony.keys

  # This directive specify the file into which chronyd will store the rate
  # information.
  driftfile /var/lib/chrony/chrony.drift

  # Save NTS keys and cookies.
  ntsdumpdir /var/lib/chrony

  # Uncomment the following line to turn logging on.
  #log tracking measurements statistics

  # Log files location.
  logdir /var/log/chrony

  # Stop bad estimates upsetting machine clock.
  maxupdateskew 100.0

  # This directive enables kernel synchronisation (every 11 minutes) of the
  # real-time clock. Note that it can’t be used along with the 'rtcfile' directive.
  rtcsync

  # Step the system clock instead of slewing it if the adjustment is larger than
  # one second, but only in the first three clock updates.
  makestep 1 3

  # Get TAI-UTC offset and leap seconds from the system tz database.
  # This directive must be commented out when using time sources serving
  # leap-smeared time.
  leapsectz right/UTC
  server 10.200.200.190 iburst

  ```

  ```
  [Unit]
  Description=Docker Application Container Engine
  Documentation=http://docs.docker.io
  [Service]
  Environment="PATH=/opt/kube/bin:/bin:/sbin:/usr/bin:/usr/sbin"
  ExecStart=/opt/kube/bin/dockerd
  ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT
  ExecReload=/bin/kill -s HUP $MAINPID
  Restart=on-failure
  RestartSec=5
  LimitNOFILE=infinity
  LimitNPROC=infinity
  LimitCORE=infinity
  Delegate=yes
  KillMode=process
  [Install]
  WantedBy=multi-user.target

  ```

  ```
  [Unit]
  Description=containerd container runtime
  Documentation=https://containerd.io
  After=network.target

  [Service]
  Environment="PATH=/opt/kube/bin/containerd-bin:/bin:/sbin:/usr/bin:/usr/sbin"
  ExecStartPre=-/sbin/modprobe overlay
  ExecStart=/opt/kube/bin/containerd-bin/containerd --log-level warn
  Restart=always
  RestartSec=5
  Delegate=yes
  KillMode=process
  OOMScoreAdjust=-999
  LimitNOFILE=1048576
  # Having non-zero Limit*s causes performance problems due to accounting overhead
  # in the kernel. We recommend using cgroups to do container-local accounting.
  LimitNPROC=infinity
  LimitCORE=infinity

  [Install]
  WantedBy=multi-user.target

  ```

  ```
  [Unit]
  Description=Etcd Server
  After=network.target
  After=network-online.target
  Wants=network-online.target
  Documentation=https://github.com/coreos

  [Service]
  Type=notify
  WorkingDirectory=/var/lib/etcd
  ExecStart=/opt/kube/bin/etcd \
    --name=etcd-10.200.200.170 \
    --cert-file=/etc/kubernetes/ssl/etcd.pem \
    --key-file=/etc/kubernetes/ssl/etcd-key.pem \
    --peer-cert-file=/etc/kubernetes/ssl/etcd.pem \
    --peer-key-file=/etc/kubernetes/ssl/etcd-key.pem \
    --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
    --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \
    --initial-advertise-peer-urls=https://10.200.200.170:2380 \
    --listen-peer-urls=https://10.200.200.170:2380 \
    --listen-client-urls=https://10.200.200.170:2379,http://127.0.0.1:2379 \
    --advertise-client-urls=https://10.200.200.170:2379 \
    --initial-cluster-token=etcd-cluster-0 \
    --initial-cluster=etcd-10.200.200.170=https://10.200.200.170:2380 \
    --initial-cluster-state=new \
    --data-dir=/var/lib/etcd \
    --wal-dir= \
    --snapshot-count=50000 \
    --auto-compaction-retention=1 \
    --auto-compaction-mode=periodic \
    --max-request-bytes=10485760 \
    --quota-backend-bytes=8589934592
  Restart=always
  RestartSec=15
  LimitNOFILE=65536
  OOMScoreAdjust=-999

  [Install]
  WantedBy=multi-user.target
  ```

#### 3. Etcd 部署类型 (spec.etcd)
- **type: kubeadm**
  - **行为**：Etcd 以 Static Pod 运行。
  - **默认值**：若未配置版本，默认跟随 Kubernetes 版本对应的推荐 Etcd 版本。
- **type: kubexm**
  - **行为**：Etcd 以 Systemd 二进制服务运行。
  - **依赖**：不依赖 Kubelet，通常在 K8s 组件启动前就绪。
- **type: Exist**
  - **行为**：不部署 Etcd，直接使用外部集群。
  - **依赖**：etcd.external_endpoints 必须配置（不能为空），且需提供对应的证书路径。

#### 4. 运行时与网络 (spec.runtime & spec.network)
- **运行时 (runtime)**
  - **containerd**：默认推荐。
  - **docker**：若选择 Docker，系统逻辑强制要求启用 cri-dockerd，因为 K8s 1.24+ 已移除 DockerShim。
  - **crio**：要求版本必须与 kubernetes.version 主版本一致。
- **网络 (network)**
  - **calico**：需自动计算 IP detection method（基于 interface 字段）。
  - **flannel**：相对简单，依赖 pod_cidr。
  - **cilium**：若内核版本过低（<4.19），代码应发出警告或报错。


#### 5. 负载均衡配置逻辑矩阵 (核心复杂场景)
代码层需根据 enabled、mode、type 以及 kubernetes.type 的组合来决定执行路径。

##### 场景组 A：不启用负载均衡
**逻辑判定**：spec.loadbalancer.enabled == false
**适用场景**：
- Kubeadm模式下单Master, Master 节点的 API Server 仅绑定本机 IP， worker节点的kubelet连接apiserver也通过master的ip
- Kubexm模式下单Master, Master 节点的 API Server 仅绑定本机 IP， worker节点的kubelet连接apiserver也通过master的ip
- kubeadm模式下多Master但强行关闭LB，, Master 节点的 API Server 仅绑定本机 IP， worker节点的kubelet连接apiserver也通过第一台master的ip
- kubexm模式下多Master但强行关闭LB，, Master 节点的 API Server 仅绑定本机 IP， worker节点的kubelet连接apiserver也通过第一台master的ip
> **执行动作**：跳过所有 LB 组件（HAProxy/Nginx/Keepalived/Kube-vip）的安装。。

##### 场景组 B：Internal 模式 (本地负载均衡)
**逻辑判定**：enabled == true 且 mode == internal
**核心原理**：每个 Worker 节点上都运行一个 LB 进程（监听 6443），反向代理到所有 Master 的 API Server。

###### 子类 B1：静态 Pod 启动 (依赖 Kubeadm)

- **条件**：kubernetes.type == kubeadm
- **适用场景**：
  - Type: haproxy, 在worker上使用静态pod启动haproxy并代理到多个master
  - Type: nginx, 在worker上使用静态pod启动nginx并代理到多个master
- **执行动作**：
  1. 渲染 HAProxy 或 Nginx 的配置文件。
  2. 生成 Kubernetes **Static Pod Manifest** (.yaml)。
  3. 放置于 /etc/kubernetes/manifests/ 目录，由 Kubelet 自动拉起。

###### 子类 B2：二进制启动 (依赖 Kubexm)
- **条件**：kubernetes.type == kubexm
- **适用场景**：
  - Type: haproxy, 在worker上使用二进制启动haproxy并代理到多个master
  - Type: nginx, 在worker上使用二进制启动nginx并代理到多个master
- **执行动作**：
  1. 分发 HAProxy 或 Nginx 的二进制文件。
  2. 渲染配置文件。
  3. 创建并启动 **Systemd Service** (haproxy.service 或 nginx.service)。

##### 场景组 C：Kube-vip 模式
**逻辑判定**：enabled == true 且 mode == kube-vip, 此时type可以不填，也走kube-vip，当然也可以显性指定为kube-vip
**适用场景**：覆盖所有 K8s/Etcd 类型组合
> **执行动作**：
> 1. 忽略 loadbalancer.type (Nginx/HAProxy 不参与)。
> 2. 依赖 spec.loadbalancer.vip 和 interface。
> 3. 生成 Kube-vip 的 Static Pod Manifest (对于 Kubeadm) 或 DaemonSet/Systemd (对于 Kubexm，具体取决于实现策略，通常 Static Pod 通用性最好)。

##### 场景组 D：External 模式 (专用高可用组件)
**逻辑判定**：enabled == true 且 mode == external
**核心原理**：使用 Keepalived 抢占 VIP，配合负载均衡软件分发流量。该组合通常运行在 OS 层面（Systemd），独立于 K8s 组件生命周期。

###### 子类 D1：Kubexm-KH (Keepalived + HAProxy)
- **条件**：type == kubexm-kh
- **适用场景**：
- **执行动作**：
  1. 安装 keepalived 和 haproxy (RPM/Deb 或二进制)。
  2. 配置 Keepalived (VRRP, VIP, Check Script)。
  3. 配置 HAProxy (Frontend 绑定 VIP, Backend 指向所有 Master IP)。
  4. 启动 Systemd 服务。

###### 子类 D2：Kubexm-KN (Keepalived + Nginx)
- **条件**：type == kubexm-kn
- **适用场景**：
- **执行动作**：
  1. 安装 keepalived 和 nginx。
  2. 配置 Keepalived。
  3. 配置 Nginx (Stream 模块, Upstream 指向所有 Master IP)。
  4. 启动 Systemd 服务。

#### 6. 配置默认值策略 (代码实现建议)
为了减少用户配置负担，解析配置时应应用以下默认值逻辑：

1. **Registry**:
   - 若 mode == offline 且 registry.enable 未指定 -> 设为 true。
   - 若 mode == online 且 registry.enable 未指定 -> 设为 false。
2. **LoadBalancer**:
   - 若 masters_count == 1 -> 强制 enabled = false (或发出警告)。
   - 若 masters_count > 1 且 enabled 未指定 -> 设为 true (默认需 HA)。
   - 若 enabled == true 且 mode 未指定 -> 默认为 external 或 internal (视具体策略定)。
3. **Etcd**:
   - 若 etcd.type 未指定 -> 默认为 kubernetes.type 的值 (保持同构)。
4. **Runtime**:
   - 若 runtime.type 未指定 -> 默认为 containerd。
   - 若 runtime.docker.cri_dockerd.enabled 未指定且 type 为 docker -> 强制设为 true。



## 检查主机的连通性
```
ping -c 4 192.168.1.100
```

## 检查主机是否安装了socat、conntrack、containerd等
```
command -v socat
conntrack --version
command -v conntrack
ctr --version
```
## 安装系统依赖
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
- 注意online模式下直接调用包管理器安装
- offline模式下，需要先将依赖打包成iso，放置到kubexm/packages/iso/${os_name}/${os_version}/${arch}/${os_name}_${os_version}_${arch}.iso，然后将此文件复制到/tmp下，然后使用mount挂载，并将包管理器的源指向此处
  - 分发 ISO 文件
  将控制端准备好的 ISO 文件 SCP 复制到目标节点的临时目录
    - 源路径：kubexm/packages/iso/...
    - 目标路径：/tmp/${os_name}_${os_version}_${arch}.iso
  - 挂载 ISO 镜像
  在目标节点创建挂载点并挂载 ISO
    ```
    mkdir -p /mnt/kubexm_iso
    mount -o loop /tmp/xxx.iso /mnt/kubexm_iso
    ```
  - 配置本地软件源 (Local Repo)
    - 针对 RPM 系系统 (CentOS/Rocky/Alma/Kylin/UOS)
      - 备份原有源：将 /etc/yum.repos.d/ 下的所有 .repo 文件移动到备份目录（防止安装时因连接超时失败）。
      - 创建本地源文件 /etc/yum.repos.d/kubexm-local.repo
        ```
        [kubexm-local]
        name=Kubexm Local Repository
        baseurl=file:///mnt/kubexm_iso
        gpgcheck=0
        enabled=1
        ```
      - 清理缓存：yum clean all && yum makecache
    - 针对 Deb 系系统 (Ubuntu/Debian)
      - 备份原有源：备份 /etc/apt/sources.list
      - 修改源文件：在 /etc/apt/sources.list 头部添加本地源路径
        ```
        deb [trusted=yes] file:///mnt/kubexm_iso ./
        ```
      - 更新缓存：apt-get update
  - 执行安装
    ```
    yum install -y
    apt-get install -y
    ```
  - 环境清理
  安装完成后执行清理动作：
    - 卸载 ISO：umount /mnt/kubexm_iso
    - 删除临时 ISO 文件：rm -f /tmp/xxx.iso
    - 恢复之前的 .repo 或 sources.list 备份文件
- 注意不同的操作系统包名可能不一样
- 注意haproxy、nginx、keepalived要根据条件安装，默认不安装
  - 如果loadbalancer启用mode为external且type为kubexm-kh, 则在loadbalancer组的机器上安装keepalived、haproxy
  - 如果loadbalancer启用mode为external且type为kubexm-kn, 则在loadbalancer组的机器上安装keepalived、nginx
  - 如果loadbalancer启用mode为internal且kubernetes.type为kubexm，loadBalancer.type为haproxy,则在所有worker上部署haproxy
  - 如果loadbalancer启用mode为internal且kubernetes.type为kubexm，loadBalancer.type为nginx,则在所有worker上部署nginx

## 禁用swap
```
swapoff -a
sed -i /^[^#]*swap*/s/^/\#/g /etc/fstab
```
- **动作**：
  - swapoff -a：立即关闭当前系统运行中的所有 Swap 分区。
  - sed ... /etc/fstab：修改文件系统挂载表，注释掉包含 "swap" 的行，防止服务器重启后 Swap 自动重新挂载。
- **目的**：**Kubernetes 的强制要求**。Kubelet（K8s 的节点代理）默认情况下如果在检测到 Swap 开启会拒绝启动。因为 Swap 会导致内存计算不准确，影响调度器的决策和 Pod 的性能稳定性。

## 禁用 SELinux
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

## 关闭系统防火墙
```
systemctl stop firewalld ...
systemctl disable firewalld ...
systemctl stop ufw ...
systemctl disable ufw ...
```
- **动作**：停止并禁用 CentOS 的 firewalld 和 Ubuntu 的 ufw 服务。
- **目的**：**防止网络规则冲突**。Kubernetes 拥有自己的网络管理机制（通过 iptables 或 IPVS 动态生成规则）。宿主机的防火墙规则容易屏蔽 Pod 流量或服务端口，导致集群网络不通。

## 加载基础内核模块 (Overlay & Bridge)
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

## 加载 IPVS 模块 (高性能网络)
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

## 内核参数 (Sysctl) 优化与去重
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

## 配置集群 Hosts 解析
```
sed -i ':a;$!{N;ba};s@# kubexm hosts BEGIN.*# kubexm hosts END@@' /etc/hosts
...
cat >>/etc/hosts<<EOF
# kubexm hosts BEGIN
172.30.1.12  node2.cluster.local node2
...
172.30.1.12  lb.kubesphere.local
# kubexm hosts END
EOF
```
- **动作**：先清理旧的 Kubekey 标记块，然后写入新的 IP 与主机名映射。
- **目的**：**节点互信与内部通信**。
  - 确保集群内所有节点（Node1-Node9）可以通过主机名相互 Ping 通。
  - lb.kubesphere.local 通常用于指向集群的负载均衡器地址（API Server 的高可用入口）。
  - dockerhub.kubekey.local 可能是配置了私有镜像仓库地址。

## 兼容性调整与资源限制
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



#### 平台依赖

```
socat、conntrack-tools、ipset、ebtables、ethtool、ipvsadm、expect、fio、curl、wget、chrony、bash-completion、rsync、tar、gzip、unzip、sshpass、cri-o、cri-tools、conmon、haproxy、nginx、keepalived、nfs-utils、iscsi-initiator-utils
```

##### 必选依赖

```
socat、conntrack-tools、ipset、ebtables、ethtool、ipvsadm
```

##### 扩展依赖

```
expect、fio、curl、wget、chrony、bash-completion、rsync、tar、gzip、unzip、sshpass
```

##### 条件依赖
###### 如果配置文件中的运行时是cri-o
```
cri-o、cri-tools、conmon
```
###### 如果运行时是podman
```

```
#### 具体配置
##### dns_ip计算规则
```
#!/bin/bash

SERVICE_CIDR="10.96.0.0/12"

ENABLE_NODELOCAL="false"

NODELOCAL_IP="169.254.20.10"
# ===========================================

ip2int() {
    local a b c d
    IFS=. read -r a b c d <<< "$1"
    echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
}

int2ip() {
    local ui32=$1; shift
    local ip n
    for n in 1 2 3 4; do
        ip=$((ui32 & 0xff))${ip:+.}$ip
        ui32=$((ui32 >> 8))
    done
    echo "$ip"
}

get_k8s_dns_ip() {
    local cidr=$1
    local nodelocal_enabled=$2
    local nodelocal_default=$3

    if [ "$nodelocal_enabled" == "true" ]; then
        echo "$nodelocal_default"
        return
    fi


    local base_ip=$(echo "$cidr" | cut -d'/' -f1)

    local base_int=$(ip2int "$base_ip")

    local dns_int=$((base_int + 10))

    int2ip "$dns_int"
}

DNS_IP=$(get_k8s_dns_ip "$SERVICE_CIDR" "$ENABLE_NODELOCAL" "$NODELOCAL_IP")

echo "配置信息:"
echo "  Service CIDR : $SERVICE_CIDR"
echo "  NodeLocal    : $ENABLE_NODELOCAL"
echo "--------------------------------"
echo "计算得出的 DNS IP: $DNS_IP"
```
