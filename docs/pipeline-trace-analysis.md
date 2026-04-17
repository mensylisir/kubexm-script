# Pipeline Call Chain Analysis Report

**Generated**: 2026-04-15
**Purpose**: Trace all pipeline call chains, analyze parameters and branches, ensure production stability

---

## Table of Contents

1. [Pipeline Architecture Overview](#pipeline-architecture-overview)
2. [Core Pipeline Utilities](#core-pipeline-utilities)
3. [Cluster Lifecycle Pipelines](#cluster-lifecycle-pipelines)
4. [Asset Management Pipelines](#asset-management-pipelines)
5. [Parameter Analysis](#parameter-analysis)
6. [Branch Logic Analysis](#branch-logic-analysis)
7. [Production Stability Issues](#production-stability-issues)
8. [Recommendations](#recommendations)

---

## Pipeline Architecture Overview

### Architecture Layers

```
CLI Entry Point (bin/kubexm)
    ↓
Pipeline Layer (internal/pipeline/)
    ↓
Module Layer (internal/module/)
    ↓
Task Layer (internal/task/)
    ↓
Step Layer (internal/step/)
    ↓
Runner Layer (internal/runner/)
    ↓
Connector Layer (internal/connector/)
```

### Pipeline Categories

1. **Cluster Lifecycle Pipelines** (19 pipelines)
   - Create, Delete, Scale-out, Scale-in
   - Upgrade (Kubernetes & ETCD)
   - Backup, Restore
   - Health Check, Reconfigure
   - Certificate Renewal (4 types)

2. **Asset Management Pipelines** (4 pipelines)
   - Download, Push Images
   - Manifests, ISO Build

3. **Registry Pipelines** (2 pipelines)
   - Create Registry, Delete Registry

---

## Core Pipeline Utilities

### File: `internal/utils/pipeline.sh`

#### 1. Timeout Control Mechanism

**Function**: `pipeline::start_timeout_watchdog()`
- **Default timeout**: 3600 seconds (1 hour)
- **Environment variable**: `KUBEXM_PIPELINE_TIMEOUT`
- **Implementation**: Background sleep process that sends SIGTERM on timeout
- **Cleanup**: `pipeline::stop_timeout_watchdog()` kills watchdog PID

**Usage Pattern**:
```bash
pipeline::start_timeout_watchdog
trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog' EXIT
```

**Timeout Values by Pipeline**:
| Pipeline | Timeout (seconds) | Reason |
|----------|------------------|---------|
| Create Cluster | 3600 (default) | Full installation |
| Delete Cluster | 3600 (default) | Cleanup operations |
| Scale-out/in | 300 (lock wait) | Node operations |
| Upgrade Cluster | 600 (lock wait) | Rolling upgrade |
| Upgrade ETCD | 600 (lock wait) | Critical data store |
| Backup/Restore | 300-600 (lock wait) | Snapshot operations |
| Cert Renewal | 600 (lock wait) | Certificate regeneration |

#### 2. Rollback Stack Management

**Functions**:
- `pipeline::register_rollback(description, command)` - Register rollback action
- `pipeline::_rollback_all()` - Execute all rollbacks in reverse order
- `pipeline::clear_rollback_stack()` - Clear stack after success

**Current Usage**:
- Only used in `create_cluster.sh`:
  - ETCD removal on failure
  - Kubernetes reset on failure

**Gap Identified**: Most pipelines do NOT implement rollback mechanisms!

#### 3. Progress Tracking

**Functions**:
- `pipeline::init_progress(total_steps)` - Initialize step counter
- `pipeline::step_start(name)` - Mark step start with percentage
- `pipeline::step_complete(name)` - Mark step completion
- `pipeline::step_skip(name)` - Track skipped steps
- `pipeline::step_fail(name)` - Track failed steps
- `pipeline::summary()` - Print final summary

**Usage**: Only implemented in `create_cluster.sh` (12 steps tracked)

#### 4. Concurrent Locking (flock-based)

**Functions**:
- `pipeline::acquire_lock(cluster_name, timeout_seconds)` - Acquire exclusive lock
- `pipeline::release_lock(cluster_name)` - Release lock

**Lock Details**:
- **Location**: `/tmp/kubexm-locks/${cluster_name}.lock`
- **Mechanism**: File descriptor 9 with flock
- **Lock Content**: PID, pipeline name, timestamp
- **Default Wait Time**: 300 seconds (5 minutes)

**All Production Pipelines Use Locking**: ✅ Yes

---

## Cluster Lifecycle Pipelines

### 1. Create Cluster Pipeline

**File**: `internal/pipeline/cluster/create_cluster.sh`
**Entry**: `pipeline::create_cluster(ctx, ...args)`
**CLI**: `kubexm create cluster --cluster=NAME`

#### Call Chain:

```
CLI: kubexm create cluster
  → pipeline::create_cluster(ctx, args...)
    ├─ Parse --cluster parameter
    ├─ Validate config.yaml and host.yaml exist
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    ├─ module::cluster_collect_config()
    │
    ├─ [Online Mode Branch]
    │   └─ module::download()
    │
    ├─ [Offline Mode + Registry Branch]
    │   ├─ module::registry_create()
    │   └─ module::push_images()
    │       └─ [On Failure] module::registry_delete()
    │
    ├─ Step 1: Preflight
    │   ├─ module::preflight_connectivity_strict()
    │   └─ module::preflight()
    │
    ├─ Step 2: Certs
    │   └─ module::certs_init()
    │
    ├─ Step 3: LoadBalancer
    │   └─ module::lb_install()
    │
    ├─ Step 4: Runtime
    │   ├─ module::runtime_collect_config()
    │   └─ module::runtime_install()
    │
    ├─ Step 5: ETCD [Conditional: etcd_type == "kubexm"]
    │   ├─ module::etcd_install()
    │   └─ register_rollback("Remove ETCD", "module::etcd_delete")
    │
    ├─ Step 6: Kubernetes
    │   ├─ module::kubernetes_install()
    │   └─ register_rollback("Reset Kubernetes", "task::kubeadm::reset")
    │
    ├─ Step 7: CNI
    │   ├─ module::cni_collect_config()
    │   ├─ module::cni_render()
    │   ├─ module::cni_install_binaries()
    │   └─ module::cni_install()
    │
    ├─ Step 8: Addons
    │   ├─ module::addons_collect_config()
    │   ├─ module::addons_render()
    │   ├─ module::addons_install()
    │   ├─ module::addons_cert_renew()
    │   └─ module::addons_etcd_backup()
    │
    └─ Step 9: SmokeTest
        └─ task::smoke_test()
```

#### Parameters:
- `--cluster=NAME` (required)
- All other params passed through to modules

#### Branches:
1. **Dry-run mode**: Early return if `KUBEXM_DRY_RUN=true`
2. **Online vs Offline mode**: Based on `config::get_mode()`
3. **Registry creation**: If offline + `config::get_registry_enabled() == true`
4. **ETCD type**: Skip ETCD install if not "kubexm" type

#### Error Handling:
- ✅ Timeout watchdog
- ✅ Cluster lock (300s wait)
- ✅ Rollback for ETCD and Kubernetes
- ✅ Auto-cleanup registry on push failure
- ❌ No rollback for LB, Runtime, CNI, Addons

---

### 2. Delete Cluster Pipeline

**File**: `internal/pipeline/cluster/delete_cluster.sh`
**Entry**: `pipeline::delete_cluster_main(ctx, ...args)`
**CLI**: `kubexm delete cluster --cluster=NAME [--force]`

#### Call Chain:

```
CLI: kubexm delete cluster
  → pipeline::delete_cluster_main(ctx, args...)
    ├─ Parse --cluster, --force
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ [Confirmation Branch: !force && interactive]
    │   └─ read user confirmation ("yes")
    │
    ├─ Acquire lock (300s)
    ├─ Start timeout watchdog
    │
    └─ pipeline::delete_cluster(ctx, args...)
        ├─ pipeline::delete_precheck()
        │   ├─ module::preflight_connectivity_permissive()
        │   └─ task::cluster::validate()
        │
        ├─ pipeline::delete_workloads()
        │   └─ task::cluster::workloads::remove()
        │
        ├─ pipeline::delete_addons()
        │   └─ module::addons_delete()
        │
        ├─ pipeline::delete_network()
        │   └─ module::cni_delete()
        │
        ├─ pipeline::delete_etcd()
        │   └─ module::etcd_delete()
        │
        ├─ pipeline::delete_hosts()
        │   └─ task::hosts::cleanup()
        │
        ├─ pipeline::delete_kubernetes()
        │   ├─ task::kubelet::remove()
        │   └─ task::kubeadm::reset()
        │
        └─ pipeline::delete_runtime()
            └─ module::runtime_delete()
```

#### Parameters:
- `--cluster=NAME` (required)
- `--force` (optional, skip confirmation)

#### Branches:
1. **Dry-run mode**: Early return
2. **Force flag**: Skip interactive confirmation
3. **Interactive check**: `-t 0` test for TTY

#### Error Handling:
- ✅ Timeout watchdog
- ✅ Cluster lock
- ✅ Interactive confirmation (unless --force)
- ❌ NO rollback mechanism
- ⚠️  Destructive operation - irreversible!

---

### 3. Upgrade Cluster Pipeline

**File**: `internal/pipeline/cluster/upgrade_cluster.sh`
**Entry**: `pipeline::upgrade_cluster_main(ctx, ...args)`
**CLI**: `kubexm upgrade cluster --cluster=NAME --to-version=VERSION`

#### Call Chain:

```
CLI: kubexm upgrade cluster
  → pipeline::upgrade_cluster_main(ctx, args...)
    ├─ Parse --cluster, --to-version
    ├─ Validate version format (v?X.Y.Z)
    ├─ Strip 'v' prefix from version
    ├─ Set KUBEXM_UPGRADE_TO_VERSION
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ Acquire lock (600s - longer for upgrade)
    ├─ Start timeout watchdog
    │
    └─ pipeline::upgrade_cluster(ctx, args...)
        ├─ pipeline::upgrade_precheck()
        │   ├─ module::preflight_connectivity_strict()
        │   ├─ task::upgrade_check_version() [HARD CHECK]
        │   └─ task::upgrade_precheck()
        │
        ├─ pipeline::upgrade_backup()
        │   └─ task::upgrade_precheck::backup()
        │       └─ [On Failure] Warn but continue
        │
        ├─ pipeline::upgrade_control_plane()
        │   └─ task::upgrade_control_plane()
        │
        ├─ pipeline::upgrade_cni()
        │   └─ module::upgrade_cni()
        │
        ├─ pipeline::upgrade_workers()
        │   └─ task::upgrade_workers()
        │
        └─ pipeline::upgrade_addons()
            └─ task::upgrade_addons()
```

#### Parameters:
- `--cluster=NAME` (required)
- `--to-version=VERSION` (required, format: v1.28.0 or 1.28.0)

#### Branches:
1. **Dry-run mode**: Early return
2. **Version validation**: Regex pattern `^v?[0-9]+\.[0-9]+\.[0-9]+$`
3. **Backup failure**: Warn but continue (non-blocking)

#### Error Handling:
- ✅ Timeout watchdog (600s lock)
- ✅ Cluster lock (longer timeout)
- ✅ Version compatibility check (hard block)
- ✅ Pre-upgrade backup (soft fail)
- ❌ NO rollback mechanism
- ⚠️  No post-upgrade validation/smoke test

---

### 4. Upgrade ETCD Pipeline

**File**: `internal/pipeline/cluster/upgrade_etcd.sh`
**Entry**: `pipeline::upgrade_etcd_main(ctx, ...args)`
**CLI**: `kubexm upgrade etcd --cluster=NAME --to-version=VERSION`

#### Call Chain:

```
CLI: kubexm upgrade etcd
  → pipeline::upgrade_etcd_main(ctx, args...)
    ├─ Parse --cluster, --to-version
    ├─ Validate version format
    ├─ Set KUBEXM_UPGRADE_TO_VERSION
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ Acquire lock (600s)
    ├─ Start timeout watchdog
    │
    ├─ module::preflight_connectivity_strict()
    │
    └─ pipeline::upgrade_etcd(ctx, args...)
        ├─ pipeline::upgrade_etcd_precheck()
        │   └─ task::upgrade_validate()
        │
        ├─ pipeline::upgrade_etcd_backup()
        │   └─ task::upgrade_backup()
        │       └─ [On Failure] Warn but continue
        │
        └─ pipeline::upgrade_etcd_do()
            └─ task::upgrade_etcd()
```

#### Parameters:
- `--cluster=NAME` (required)
- `--to-version=VERSION` (required, format: v3.5.13 or 3.5.13)

#### Branches:
1. **Dry-run mode**: Early return
2. **Version validation**: Same regex as cluster upgrade
3. **Backup failure**: Warn but continue

#### Error Handling:
- ✅ Timeout watchdog (600s lock)
- ✅ Strict connectivity check
- ✅ Pre-upgrade backup (soft fail)
- ❌ NO rollback mechanism
- ⚠️  ETCD is critical - should have stronger safeguards

---

### 5. Scale-out Cluster Pipeline

**File**: `internal/pipeline/cluster/scaleout_cluster.sh`
**Entry**: `pipeline::scaleout_cluster_main(ctx, ...args)`
**CLI**: `kubexm scale cluster --cluster=NAME [--role=ROLE] [--nodes=NODES]`

#### Call Chain:

```
CLI: kubexm scale cluster
  → pipeline::scaleout_cluster_main(ctx, args...)
    ├─ Parse --cluster, --role, --nodes
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ [If --nodes specified]
    │   └─ export KUBEXM_SCALE_NODES
    │
    ├─ Acquire lock (300s)
    ├─ Start timeout watchdog
    │
    ├─ [If --role specified] BRANCH
    │   ├─ worker → pipeline::scaleout_workers()
    │   ├─ control-plane|master → pipeline::scaleout_control_plane()
    │   ├─ etcd → pipeline::scaleout_etcd()
    │   └─ pipeline::scaleout_post()
    │
    └─ [Default: all roles]
        └─ pipeline::scaleout_cluster(ctx, args...)
            ├─ pipeline::scaleout_precheck()
            │   ├─ module::preflight_connectivity_permissive()
            │   └─ task::cluster::validate()
            │
            ├─ pipeline::scaleout_workers()
            │   ├─ task::collect_workers_info()
            │   ├─ task::collect_workers_join_cmd()
            │   ├─ task::join_workers()
            │   └─ task::wait_nodes_ready()
            │
            ├─ pipeline::scaleout_control_plane()
            │   └─ task::scale_out_cp()
            │
            ├─ pipeline::scaleout_etcd()
            │   └─ [If etcd_type == "kubexm"]
            │       └─ module::etcd_install()
            │
            └─ pipeline::scaleout_post()
                └─ task::scale_update_hosts()
```

#### Parameters:
- `--cluster=NAME` (required)
- `--role=ROLE` (optional: worker, control-plane, master, etcd)
- `--nodes=NODES` (optional, comma-separated node list)

#### Branches:
1. **Dry-run mode**: Early return
2. **Role-specific scaling**: If `--role` provided, only scale that role
3. **ETCD type**: Skip ETCD scale-out if not "kubexm" type
4. **Node selection**: If `--nodes` provided, use specific nodes

#### Error Handling:
- ✅ Timeout watchdog
- ✅ Cluster lock
- ✅ Role validation
- ❌ NO rollback mechanism
- ⚠️  No validation of minimum node count before scale-in

---

### 6. Scale-in Cluster Pipeline

**File**: `internal/pipeline/cluster/scalein_cluster.sh`
**Entry**: `pipeline::scalein_cluster_main(ctx, ...args)`
**CLI**: `kubexm scale cluster --cluster=NAME [--role=ROLE] [--nodes=NODES]`

#### Call Chain:

```
CLI: kubexm scale cluster
  → pipeline::scalein_cluster_main(ctx, args...)
    ├─ Parse --cluster, --role, --nodes
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ [If --nodes specified]
    │   └─ export KUBEXM_SCALE_NODES
    │
    ├─ Acquire lock (300s)
    ├─ Start timeout watchdog
    │
    ├─ [If --role specified] BRANCH
    │   ├─ worker → pipeline::scalein_workers()
    │   ├─ control-plane|master → pipeline::scalein_control_plane()
    │   ├─ etcd → pipeline::scalein_etcd()
    │   └─ pipeline::scalein_post()
    │
    └─ [Default: all roles]
        └─ pipeline::scalein_cluster(ctx, args...)
            ├─ pipeline::scalein_precheck()
            │   ├─ module::preflight_connectivity_permissive()
            │   └─ task::cluster::validate()
            │
            ├─ pipeline::scalein_workers()
            │   ├─ task::drain_workers()
            │   ├─ task::stop_kubelet_workers()
            │   ├─ task::kubeadm_reset_workers()
            │   ├─ task::cleanup_dirs_workers()
            │   ├─ task::flush_iptables()
            │   └─ task::update_lb_config()
            │
            ├─ pipeline::scalein_control_plane()
            │   └─ task::scale_in_cp()
            │
            ├─ pipeline::scalein_etcd()
            │   └─ [If etcd_type == "kubexm"]
            │       └─ module::etcd_delete()
            │
            └─ pipeline::scalein_post()
                └─ task::scale_update_hosts()
```

#### Parameters:
- Same as scale-out

#### Branches:
- Same as scale-out

#### Error Handling:
- ✅ Timeout watchdog
- ✅ Cluster lock
- ✅ Drain workers before removal
- ❌ NO rollback mechanism
- ⚠️  No quorum check for ETCD/Control-plane before removal
- ⚠️  No minimum node count validation

---

### 7. Backup Cluster Pipeline

**File**: `internal/pipeline/cluster/backup.sh`
**Entry**: `pipeline::backup_cluster(ctx, ...args)`
**CLI**: `kubexm backup cluster --cluster=NAME [--path=PATH]`

#### Call Chain:

```
CLI: kubexm backup cluster
  → pipeline::backup_cluster(ctx, args...)
    ├─ Parse --cluster, --path
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ [If --path specified]
    │   ├─ context::set("etcd_backup_path", path)
    │   └─ export KUBEXM_BACKUP_PATH
    │
    ├─ Acquire lock (300s)
    ├─ Start timeout watchdog
    │
    ├─ module::preflight_connectivity_permissive()
    │
    └─ module::etcd_backup()
```

#### Parameters:
- `--cluster=NAME` (required)
- `--path=PATH` (optional, custom backup path)

#### Branches:
1. **Dry-run mode**: Early return
2. **Custom backup path**: If provided, override default

#### Error Handling:
- ✅ Timeout watchdog
- ✅ Cluster lock
- ✅ Connectivity check
- ❌ NO backup verification
- ❌ NO rollback mechanism
- ⚠️  No backup size/integrity validation

---

### 8. Restore Cluster Pipeline

**File**: `internal/pipeline/cluster/restore.sh`
**Entry**: `pipeline::restore_cluster(ctx, ...args)`
**CLI**: `kubexm restore cluster --cluster=NAME --path=PATH [--force]`

#### Call Chain:

```
CLI: kubexm restore cluster
  → pipeline::restore_cluster(ctx, args...)
    ├─ Parse --cluster, --path, --force
    ├─ Validate required params (--cluster, --path)
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ export KUBEXM_RESTORE_PATH
    │
    ├─ Validate backup file exists
    │
    ├─ [Confirmation Branch: !force && interactive]
    │   └─ read user confirmation ("yes")
    │
    ├─ module::preflight_connectivity_permissive()
    │
    ├─ Acquire lock (600s - longer for restore)
    ├─ Start timeout watchdog
    │
    └─ module::etcd_restore()
```

#### Parameters:
- `--cluster=NAME` (required)
- `--path=PATH` (required, backup file path)
- `--force` (optional, skip confirmation)

#### Branches:
1. **Dry-run mode**: Early return
2. **Force flag**: Skip interactive confirmation
3. **Interactive check**: `-t 0` test for TTY

#### Error Handling:
- ✅ Timeout watchdog (600s lock)
- ✅ Cluster lock
- ✅ Backup file existence check
- ✅ Interactive confirmation (unless --force)
- ❌ NO pre-restore backup
- ❌ NO rollback mechanism
- ⚠️  IRREVERSIBLE operation - current data overwritten!

---

### 9. Health Check Pipeline

**File**: `internal/pipeline/cluster/health.sh`
**Entry**: `pipeline::health_cluster(ctx, ...args)`
**CLI**: `kubexm health cluster --cluster=NAME [--check=TYPE] [--output-format=FORMAT]`

#### Call Chain:

```
CLI: kubexm health cluster
  → pipeline::health_cluster(ctx, args...)
    ├─ Parse --cluster, --check, --output-format
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ export KUBEXM_HEALTH_OUTPUT_FORMAT
    │
    ├─ module::preflight_connectivity_permissive()
    │
    ├─ [Check Type Branch]
    │   ├─ all → task::health_check_all()
    │   ├─ node → task::health_check_nodes()
    │   ├─ component → task::health_check_components()
    │   ├─ workload → task::health_check_workloads()
    │   └─ connectivity → task::health_check_connectivity()
    │
    └─ [If output-format == "json"]
        └─ health::output_json(check_type, exit_code)
```

#### Parameters:
- `--cluster=NAME` (required)
- `--check=TYPE` (optional: all, node, component, workload, connectivity; default: all)
- `--output-format=FORMAT` (optional: text, json; default: text)

#### Branches:
1. **Dry-run mode**: Early return
2. **Check type selection**: Switch-case on check type
3. **Output format**: JSON if requested

#### Error Handling:
- ✅ Returns proper exit codes
- ✅ JSON output support
- ❌ No timeout/locking (read-only operation)
- ⚠️  No retry logic for transient failures

---

### 10. Reconfigure Cluster Pipeline

**File**: `internal/pipeline/cluster/reconfigure.sh`
**Entry**: `pipeline::reconfigure_cluster(ctx, ...args)`
**CLI**: `kubexm reconfigure cluster --cluster=NAME [--target=COMPONENT]`

#### Call Chain:

```
CLI: kubexm reconfigure cluster
  → pipeline::reconfigure_cluster(ctx, args...)
    ├─ Parse --cluster, --target
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    │
    ├─ Acquire lock (300s)
    ├─ Start timeout watchdog
    │
    ├─ module::preflight_connectivity_permissive()
    │
    ├─ [Target Branch]
    │   ├─ all (or empty)
    │   │   ├─ module::runtime_reconfigure()
    │   │   ├─ module::etcd_reconfigure()
    │   │   ├─ module::cni_reconfigure()
    │   │   ├─ module::lb_reconfigure()
    │   │   ├─ module::addons_reconfigure()
    │   │   └─ module::os_update_hosts()
    │   │
    │   ├─ runtime → module::runtime_reconfigure()
    │   ├─ etcd → module::etcd_reconfigure()
    │   ├─ cni → module::cni_reconfigure()
    │   ├─ lb|loadbalancer → module::lb_reconfigure()
    │   ├─ addons → module::addons_reconfigure()
    │   └─ hosts → module::os_update_hosts()
    │
    └─ Release lock
```

#### Parameters:
- `--cluster=NAME` (required)
- `--target=COMPONENT` (optional: all, runtime, etcd, cni, lb, loadbalancer, addons, hosts; default: all)

#### Branches:
1. **Dry-run mode**: Early return
2. **Target selection**: Case statement for component targeting

#### Error Handling:
- ✅ Timeout watchdog
- ✅ Cluster lock
- ✅ Connectivity check
- ❌ NO rollback mechanism
- ⚠️  No configuration validation before apply
- ⚠️  No service restart verification

---

### 11-14. Certificate Renewal Pipelines

**Files**:
- `internal/pipeline/cluster/renew_kubernetes_ca.sh`
- `internal/pipeline/cluster/renew_kubernetes_certs.sh`
- `internal/pipeline/cluster/renew_etcd_ca.sh`
- `internal/pipeline/cluster/renew_etcd_certs.sh`

**Pattern**: All four follow identical structure

#### Call Chain (example: renew_kubernetes_ca):

```
CLI: kubexm renew kubernetes-ca
  → pipeline::renew_kubernetes_ca(ctx, args...)
    ├─ Parse --cluster
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    ├─ config::validate_consistency()
    │
    ├─ KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq"
    ├─ module::check_tools()
    │
    ├─ Acquire lock (600s)
    ├─ Start timeout watchdog
    │
    ├─ module::preflight_connectivity_strict()
    │
    └─ module::certs_renew_kubernetes_ca()
```

#### Parameters:
- `--cluster=NAME` (required)

#### Common Features:
- ✅ Tool dependency checks (jq, yq, xmjq, xmyq)
- ✅ Config consistency validation
- ✅ Timeout watchdog (600s lock)
- ✅ Cluster lock
- ✅ Strict connectivity check
- ❌ NO pre-renewal backup
- ❌ NO rollback mechanism
- ❌ NO certificate validity verification after renewal
- ⚠️  Services may need manual restart after cert renewal

---

## Asset Management Pipelines

### 15. Download Pipeline

**File**: `internal/pipeline/assets/download.sh`
**Entry**: `pipeline::download(ctx, ...args)`
**CLI**: `kubexm download --cluster=NAME`

#### Call Chain:

```
CLI: kubexm download
  → pipeline::download(ctx, args...)
    ├─ Parse --cluster (optional)
    │
    ├─ [If cluster specified]
    │   ├─ Validate config.yaml exists
    │   └─ parser::load_config()
    │
    └─ module::download()
```

#### Parameters:
- `--cluster=NAME` (optional, determines what to download)

#### Special Notes:
- Does NOT require host.yaml (downloads are machine-agnostic)
- Used for both online mode auto-download and offline preparation
- No locking needed (no cluster state modification)

#### Error Handling:
- ✅ Dry-run support
- ❌ No timeout control
- ❌ No progress tracking
- ⚠️  Large downloads may hang indefinitely

---

### 16. Push Images Pipeline

**File**: `internal/pipeline/assets/push_images.sh`
**Entry**: `pipeline::push_images(ctx, ...args)`
**CLI**: `kubexm push images [options]`

#### Call Chain:

```
CLI: kubexm push images
  → pipeline::push_images(ctx, args...)
    ├─ Parse --cluster, --packages, --manifest
    │
    ├─ [If --cluster specified]
    │   ├─ Validate config/host files
    │   ├─ parser::load_config()
    │   └─ parser::load_hosts()
    │
    ├─ [If --packages or --packages-dir]
    │   └─ export KUBEXM_REQUIRE_PACKAGES="true"
    │
    ├─ [If --manifest]
    │   └─ Add manifest-tool to KUBEXM_TOOL_CHECKS
    │
    ├─ KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq skopeo"
    ├─ module::check_tools()
    │
    └─ module::push_images()
```

#### Parameters:
- `--cluster=NAME` (optional)
- `--list=FILE` (image list file)
- `--dual` (enable dual-image push)
- `--manifest` (generate multi-arch manifests)
- `--target-registry=URL` (custom registry)
- `--packages` (push from packages directory)
- `--packages-dir=DIR` (custom packages path)
- `--parallel=N` (concurrent pushes)

#### Error Handling:
- ✅ Tool dependency checks
- ✅ Dry-run support
- ❌ No timeout control
- ❌ No retry logic for failed pushes
- ⚠️  No push verification

---

### 17. Manifests Pipeline

**File**: `internal/pipeline/assets/manifests.sh`
**Entry**: `pipeline::manifests(ctx, ...args)`
**CLI**: `kubexm create manifests [options]`

#### Call Chain:

```
CLI: kubexm create manifests
  → pipeline::manifests(ctx, args...)
    └─ module::manifests()
```

#### Parameters:
- `--kubernetes-version=VER` (default: v1.32.4)
- `--kubernetes-type=TYPE` (kubeadm | kubexm)
- `--container-runtime=RT` (default: containerd)
- `--cni=PLUGIN` (default: calico)
- `--arch=ARCH` (default: amd64,arm64)
- `--cluster=NAME` (from config)

#### Error Handling:
- ✅ Dry-run support
- Simple passthrough to module

---

### 18. ISO Build Pipeline

**File**: `internal/pipeline/assets/iso.sh`
**Entry**: `pipeline::iso(ctx, ...args)`
**CLI**: `kubexm create iso [options]`

#### Call Chain:

```
CLI: kubexm create iso
  → pipeline::iso(ctx, args...)
    └─ module::iso_build()
```

#### Parameters:
- `--with-build-all` (build all systems/architectures)
- `--with-build-os=OS` (centos7, rocky9, ubuntu22)
- `--with-build-os-version=VER`
- `--with-build-arch=ARCH` (amd64, arm64)
- `--with-build-local` (local build without Docker)

#### Error Handling:
- ✅ Dry-run support
- ❌ No timeout control (ISO builds can be slow)
- ⚠️  Docker-dependent unless --with-build-local

---

### 19-20. Registry Pipelines

**File**: `internal/pipeline/cluster/registry.sh`

#### Create Registry:

```
CLI: kubexm create registry
  → pipeline::create_registry(ctx, args...)
    ├─ Parse --cluster
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    ├─ KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq"
    ├─ module::check_tools()
    └─ module::registry_create()
```

#### Delete Registry:

```
CLI: kubexm delete registry
  → pipeline::delete_registry(ctx, args...)
    ├─ Parse --cluster
    ├─ Validate config/host files
    ├─ parser::load_config()
    ├─ parser::load_hosts()
    ├─ KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq"
    ├─ module::check_tools()
    └─ module::registry_delete()
```

#### Parameters:
- `--cluster=NAME` (required)

#### Error Handling:
- ✅ Tool checks
- ✅ Dry-run support
- ❌ No locking
- ❌ No confirmation for delete
- ⚠️  Registry deletion may break image pulls

---

## Parameter Analysis

### Common Parameters Across All Pipelines

| Parameter | Required In | Optional In | Purpose |
|-----------|-------------|-------------|---------|
| `--cluster=NAME` | All cluster ops | download, push images | Cluster identification |
| `--force` | - | delete cluster, restore | Skip confirmation |
| `--to-version=VER` | upgrade cluster, upgrade etcd | - | Target version |
| `--path=PATH` | restore cluster | backup cluster | File path |
| `--check=TYPE` | - | health cluster | Check type selector |
| `--output-format=FMT` | - | health cluster | Output format |
| `--target=COMP` | - | reconfigure cluster | Component selector |
| `--role=ROLE` | - | scale cluster | Role selector |
| `--nodes=NODES` | - | scale cluster | Node selector |

### Environment Variables Used

| Variable | Set By | Used By | Purpose |
|----------|--------|---------|---------|
| `KUBEXM_CLUSTER_NAME` | All pipelines | Modules/Tasks | Cluster context |
| `KUBEXM_DRY_RUN` | User/CLI | All pipelines | Dry-run mode |
| `KUBEXM_PIPELINE_TIMEOUT` | User | pipeline.sh | Timeout override |
| `KUBEXM_PIPELINE_NAME` | Each pipeline | pipeline.sh | Logging/locking |
| `KUBEXM_UPGRADE_TO_VERSION` | Upgrade pipelines | Tasks | Target version |
| `KUBEXM_BACKUP_PATH` | Backup pipeline | ETCD module | Custom backup path |
| `KUBEXM_RESTORE_PATH` | Restore pipeline | ETCD module | Restore source |
| `KUBEXM_HEALTH_OUTPUT_FORMAT` | Health pipeline | Health tasks | Output format |
| `KUBEXM_SCALE_NODES` | Scale pipelines | Scale tasks | Node selection |
| `KUBEXM_REQUIRE_PACKAGES` | Push images | Images module | Package mode |
| `KUBEXM_TOOL_CHECKS` | Various pipelines | module::check_tools | Tool dependencies |
| `KUBEXM_SKIP_DOWNLOAD` | Create cluster | Download module | Skip re-download |

### Parameter Validation Gaps

❌ **Missing Validations**:
1. No cluster name format validation (should match `[a-z0-9-]+`)
2. No version range validation (e.g., can't downgrade)
3. No node count validation before scale-in
4. No quorum validation before removing control-plane/etcd nodes
5. No disk space validation before backup/restore
6. No network bandwidth validation before large operations

---

## Branch Logic Analysis

### Decision Points Summary

#### 1. Dry-Run Mode (All Pipelines)
```bash
if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
  logger::info "DRY-RUN enabled: planning ..."
  return 0
fi
```
**Impact**: Skips all execution, useful for testing
**Coverage**: ✅ All pipelines

#### 2. Online vs Offline Mode (Create Cluster)
```bash
mode=$(config::get_mode)
if [[ "${mode}" == "online" ]]; then
  module::download()
else
  # Offline: optional registry creation
  if [[ "${registry_enabled}" == "true" ]]; then
    module::registry_create()
    module::push_images()
  fi
fi
```
**Impact**: Different resource acquisition strategies
**Risk**: Registry cleanup on push failure

#### 3. ETCD Type Selection (Multiple Pipelines)
```bash
etcd_type=$(config::get_etcd_type)
if [[ "${etcd_type}" == "kubexm" ]]; then
  # Handle independent ETCD nodes
else
  # Skip (stacked or external ETCD)
fi
```
**Used In**:
- create_cluster (install)
- scaleout_cluster (add nodes)
- scalein_cluster (remove nodes)

#### 4. Interactive Confirmation (Destructive Ops)
```bash
if [[ "${force}" != "true" ]]; then
  if [[ -t 0 ]]; then
    read -r confirm
    if [[ "${confirm}" != "yes" ]]; then
      return 3  # Cancelled
    fi
  else
    return 3  # Non-interactive, require --force
  fi
fi
```
**Used In**:
- delete_cluster
- restore_cluster

#### 5. Role-Specific Scaling (Scale Operations)
```bash
if [[ -n "${target_role}" ]]; then
  case "${target_role}" in
    worker) ... ;;
    control-plane|master) ... ;;
    etcd) ... ;;
    *) error ;;
  esac
else
  # Scale all roles
fi
```
**Used In**:
- scaleout_cluster
- scalein_cluster

#### 6. Health Check Type Selection
```bash
case "${check_type}" in
  all) task::health_check_all() ;;
  node) task::health_check_nodes() ;;
  component) task::health_check_components() ;;
  workload) task::health_check_workloads() ;;
  connectivity) task::health_check_connectivity() ;;
  *) error ;;
esac
```

#### 7. Reconfigure Target Selection
```bash
if [[ -z "${target}" || "${target}" == "all" ]]; then
  # Reconfigure all components
else
  case "${target}" in
    runtime|etcd|cni|lb|addons|hosts) ... ;;
    *) error ;;
  esac
fi
```

### Branch Coverage Issues

⚠️ **Uncovered Scenarios**:
1. No fallback if strict connectivity fails (should offer permissive mode)
2. No graceful degradation when optional tools missing (e.g., manifest-tool)
3. No retry logic for transient failures
4. No circuit breaker for repeated failures

---

## Production Stability Issues

### 🔴 CRITICAL Issues

#### 1. Missing `pipeline::scale_cluster` Function
**Location**: `bin/kubexm:626`
**Issue**: CLI calls `pipeline::scale_cluster` but this function doesn't exist!
**Impact**: `kubexm scale cluster` command will fail with "command not found"
**Fix Required**: Create wrapper function that routes to scaleout/scalein based on node changes

#### 2. No Rollback Mechanisms (Most Pipelines)
**Affected Pipelines**:
- delete_cluster
- upgrade_cluster
- upgrade_etcd
- scaleout/scalein_cluster
- restore_cluster
- reconfigure_cluster
- All cert renewal pipelines

**Impact**: Partial failures leave clusters in inconsistent states
**Example**: Upgrade fails at worker stage → control plane upgraded, workers not → version mismatch!

#### 3. No Pre-Operation Backups (Destructive Ops)
**Affected**:
- restore_cluster (overwrites current state without backup)
- upgrade operations (backup is soft-fail, may be skipped)
- cert renewal (no CA backup before regeneration)

**Impact**: Data loss if operation fails

#### 4. Insufficient Quorum Checks
**Affected**:
- scalein_cluster (can remove last etcd/control-plane node)
- delete_cluster (no validation of cluster importance)

**Impact**: Can destroy cluster quorum, making cluster unusable

---

### 🟡 HIGH Severity Issues

#### 5. No Post-Operation Validation
**Affected**:
- upgrade_cluster (no smoke test after upgrade)
- scaleout_cluster (no node readiness verification beyond initial join)
- reconfigure_cluster (no service health check after reconfig)
- cert renewal (no certificate validity check)

**Impact**: Silent failures, issues discovered later

#### 6. Inconsistent Timeout Values
**Current State**:
- Create/Delete: 3600s (1 hour)
- Upgrade: 600s lock wait
- Scale: 300s lock wait
- Backup/Restore: Mixed (300-600s)

**Issue**: Lock wait timeout ≠ operation timeout
**Impact**: May timeout while waiting for lock, not during operation

#### 7. No Resource Validation
**Missing Checks**:
- Disk space before download/backup
- Memory availability before operations
- Network bandwidth for image pushes
- CPU capacity before adding nodes

**Impact**: Operations fail mid-way due to resource exhaustion

#### 8. Weak Error Messages
**Current**: Generic "command failed" messages
**Needed**: Actionable error messages with remediation steps

---

### 🟢 MEDIUM Severity Issues

#### 9. No Retry Logic
**Affected**: All network-dependent operations
**Examples**:
- Image pulls/pushes
- Package downloads
- API calls to Kubernetes

**Impact**: Transient network issues cause complete failures

#### 10. No Rate Limiting
**Affected**:
- push_images (can overwhelm registry)
- parallel operations

**Impact**: Service degradation during bulk operations

#### 11. Incomplete Progress Tracking
**Current**: Only create_cluster has progress tracking
**Needed**: All long-running operations should show progress

#### 12. No Operation Idempotency
**Issue**: Running same operation twice may cause errors
**Examples**:
- Creating already-existing resources
- Deleting non-existent resources

---

### 🔵 LOW Severity Issues

#### 13. Hardcoded Paths
**Examples**:
- Lock directory: `/tmp/kubexm-locks`
- Should be configurable via environment variable

#### 14. Magic Numbers
**Examples**:
- Lock timeouts: 300, 600 seconds
- Should be named constants or configurable

#### 15. Inconsistent Logging
**Issue**: Mix of `logger::` and `log::` prefixes
**Should**: Standardize on one logging interface

---

## Recommendations

### Immediate Actions (Critical)

#### 1. Fix Missing `pipeline::scale_cluster` Function

Create `/home/mensyli1/Documents/workspace/sre/kubexm-script/internal/pipeline/cluster/scale_cluster.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/pipeline/cluster/scaleout_cluster.sh"
source "${KUBEXM_ROOT}/internal/pipeline/cluster/scalein_cluster.sh"

pipeline::scale_cluster() {
  local ctx="$1"
  shift

  # Determine if this is scale-out or scale-in by comparing current vs desired nodes
  # For now, delegate to user to specify intent via host.yaml changes
  # Alternative: add --action=scale-out|scale-in parameter

  local cluster_name=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done

  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  parser::load_config
  parser::load_hosts

  # Compare current cluster state with host.yaml to determine action
  # This requires implementing node comparison logic
  # For MVP, we can check if new nodes are added or removed

  local current_workers desired_workers
  current_workers=$(kubectl get nodes --selector='node-role.kubernetes.io/worker' -o json | jq '.items | length')
  desired_workers=$(yq '.spec.hosts[] | select(.roles[] == "worker")' "${KUBEXM_HOST_FILE}" | wc -l)

  if [[ ${desired_workers} -gt ${current_workers} ]]; then
    logger::info "Detected scale-out: ${current_workers} -> ${desired_workers} workers"
    pipeline::scaleout_cluster_main "${ctx}" "$@"
  elif [[ ${desired_workers} -lt ${current_workers} ]]; then
    logger::info "Detected scale-in: ${current_workers} -> ${desired_workers} workers"
    pipeline::scalein_cluster_main "${ctx}" "$@"
  else
    logger::info "No scaling needed: ${current_workers} workers"
  fi
}
```

Then update `bin/kubexm`:
```bash
source "${KUBEXM_ROOT}/internal/pipeline/cluster/scale_cluster.sh"
```

#### 2. Implement Rollback Framework

Enhance `internal/utils/pipeline.sh` with automatic rollback registration:

```bash
# Auto-register rollback for common operations
pipeline::register_module_rollback() {
  local module="$1"
  local action="$2"
  local rollback_action="$3"

  case "${action}" in
    install)
      pipeline::register_rollback "Uninstall ${module}" "module::${module}_delete '${ctx}' || true"
      ;;
    upgrade)
      pipeline::register_rollback "Rollback ${module} upgrade" "module::${module}_rollback '${ctx}' || true"
      ;;
    configure)
      pipeline::register_rollback "Revert ${module} config" "module::${module}_revert_config '${ctx}' || true"
      ;;
  esac
}
```

Apply to all destructive operations.

#### 3. Add Pre-Operation Backups

For all destructive operations (upgrade, restore, cert renewal):

```bash
pipeline::ensure_backup() {
  local operation="$1"
  local backup_path

  logger::warn "Creating pre-${operation} backup..."
  backup_path="/tmp/kubexm-backups/${KUBEXM_CLUSTER_NAME}/pre-${operation}-$(date +%Y%m%d%H%M%S).db"

  if ! module::etcd_backup --path="${backup_path}"; then
    logger::error "Pre-${operation} backup FAILED! Aborting for safety."
    return 1
  fi

  logger::info "Backup saved to: ${backup_path}"
  export KUBEXM_PRE_OPERATION_BACKUP="${backup_path}"
}
```

Call before:
- upgrade_cluster
- upgrade_etcd
- restore_cluster (backup current state before overwrite!)
- renew_*_ca (backup old CA)

#### 4. Implement Quorum Checks

Add to scalein_cluster:

```bash
pipeline::validate_quorum_before_removal() {
  local role="$1"
  local nodes_to_remove="$2"

  local current_count desired_count min_quorum

  case "${role}" in
    etcd)
      current_count=$(etcdctl member list | wc -l)
      min_quorum=$(( (current_count / 2) + 1 ))
      desired_count=$(( current_count - nodes_to_remove ))

      if [[ ${desired_count} -lt ${min_quorum} ]]; then
        logger::error "Removing ${nodes_to_remove} etcd nodes would break quorum!"
        logger::error "Current: ${current_count}, After removal: ${desired_count}, Minimum quorum: ${min_quorum}"
        return 1
      fi
      ;;
    control-plane)
      # Similar check for control plane
      ;;
  esac
}
```

---

### Short-Term Improvements (High Priority)

#### 5. Add Post-Operation Validation

After each major operation:

```bash
pipeline::post_operation_validation() {
  local operation="$1"

  logger::info "Running post-${operation} validation..."

  case "${operation}" in
    upgrade)
      task::smoke_test "${ctx}" "$@" || {
        logger::error "Post-upgrade validation FAILED!"
        logger::error "Cluster may be in degraded state. Check logs."
        return 1
      }
      ;;
    scale-out)
      task::verify_new_nodes_ready "${ctx}" "$@" || {
        logger::warn "Some new nodes not ready. Manual intervention may be needed."
      }
      ;;
    cert-renewal)
      module::certs_verify_validity "${ctx}" "$@" || {
        logger::error "Certificate validation failed after renewal!"
        return 1
      }
      ;;
  esac
}
```

#### 6. Standardize Timeout Configuration

Create `internal/config/timeouts.sh`:

```bash
#!/usr/bin/env bash

# Timeout configurations (seconds)
KUBEXM_LOCK_TIMEOUT_CREATE="${KUBEXM_LOCK_TIMEOUT_CREATE:-300}"
KUBEXM_LOCK_TIMEOUT_DELETE="${KUBEXM_LOCK_TIMEOUT_DELETE:-300}"
KUBEXM_LOCK_TIMEOUT_UPGRADE="${KUBEXM_LOCK_TIMEOUT_UPGRADE:-600}"
KUBEXM_LOCK_TIMEOUT_SCALE="${KUBEXM_LOCK_TIMEOUT_SCALE:-300}"
KUBEXM_LOCK_TIMEOUT_BACKUP="${KUBEXM_LOCK_TIMEOUT_BACKUP:-300}"
KUBEXM_LOCK_TIMEOUT_RESTORE="${KUBEXM_LOCK_TIMEOUT_RESTORE:-600}"
KUBEXM_LOCK_TIMEOUT_CERT="${KUBEXM_LOCK_TIMEOUT_CERT:-600}"

KUBEXM_OPERATION_TIMEOUT="${KUBEXM_OPERATION_TIMEOUT:-3600}"
```

Use consistently across all pipelines.

#### 7. Add Resource Validation

Before resource-intensive operations:

```bash
pipeline::check_resources() {
  local operation="$1"
  local required_disk_mb required_memory_mb

  case "${operation}" in
    download)
      required_disk_mb=10240  # 10GB
      ;;
    backup)
      required_disk_mb=5120   # 5GB
      ;;
    # ... other operations
  esac

  local available_disk
  available_disk=$(df -m /tmp | awk 'NR==2 {print $4}')

  if [[ ${available_disk} -lt ${required_disk_mb} ]]; then
    logger::error "Insufficient disk space: ${available_disk}MB available, ${required_disk_mb}MB required"
    return 1
  fi
}
```

---

### Medium-Term Enhancements

#### 8. Implement Retry Logic

Add to `internal/utils/pipeline.sh`:

```bash
pipeline::retry_with_backoff() {
  local max_attempts="${1:-3}"
  local base_delay="${2:-5}"
  shift 2
  local cmd="$*"

  local attempt=1
  while [[ ${attempt} -le ${max_attempts} ]]; do
    logger::info "Attempt ${attempt}/${max_attempts}: ${cmd}"

    if eval "${cmd}"; then
      return 0
    fi

    if [[ ${attempt} -lt ${max_attempts} ]]; then
      local delay=$(( base_delay * attempt ))
      logger::warn "Attempt ${attempt} failed, retrying in ${delay}s..."
      sleep "${delay}"
    fi

    ((attempt++))
  done

  logger::error "Command failed after ${max_attempts} attempts: ${cmd}"
  return 1
}

# Usage:
# pipeline::retry_with_backoff 3 5 "module::push_images '${ctx}'"
```

#### 9. Add Progress Tracking to All Pipelines

Extend progress tracking beyond create_cluster:

```bash
# In each pipeline:
pipeline::init_progress <number_of_steps>
pipeline::step_start "Step Name"
# ... operation ...
pipeline::step_complete "Step Name"
# ... or on failure ...
pipeline::step_fail "Step Name"
# ... at end ...
pipeline::summary
```

#### 10. Implement Circuit Breaker Pattern

For repeated failures:

```bash
pipeline::circuit_breaker_check() {
  local operation="$1"
  local failure_count_file="/tmp/kubexm-circuit-breaker/${operation}.count"

  mkdir -p "$(dirname "${failure_count_file}")"

  local count=0
  [[ -f "${failure_count_file}" ]] && count=$(cat "${failure_count_file}")

  if [[ ${count} -ge 3 ]]; then
    logger::error "Circuit breaker OPEN for ${operation} (${count} consecutive failures)"
    logger::error "Manual intervention required. Reset with: rm ${failure_count_file}"
    return 1
  fi

  return 0
}

pipeline::record_failure() {
  local operation="$1"
  local failure_count_file="/tmp/kubexm-circuit-breaker/${operation}.count"

  local count=0
  [[ -f "${failure_count_file}" ]] && count=$(cat "${failure_count_file}")
  echo $(( count + 1 )) > "${failure_count_file}"
}

pipeline::record_success() {
  local operation="$1"
  local failure_count_file="/tmp/kubexm-circuit-breaker/${operation}.count"

  rm -f "${failure_count_file}"
}
```

---

### Long-Term Architectural Improvements

#### 11. Implement State Machine for Cluster Operations

Track cluster state transitions to prevent invalid operations:

```
States: [CREATING, RUNNING, SCALING, UPGRADING, DELETING, DEGRADED, BACKING_UP, RESTORING]

Valid Transitions:
- RUNNING → SCALING (scale operations)
- RUNNING → UPGRADING (upgrade operations)
- RUNNING → BACKING_UP (backup)
- BACKING_UP → RUNNING (backup complete)
- BACKING_UP → RESTORING (restore)
- RESTORING → RUNNING (restore complete)
- Any → DEGRADED (on failure)
- DEGRADED → RUNNING (after recovery)

Invalid Transitions (should be blocked):
- UPGRADING → SCALING (can't scale during upgrade)
- DELETING → Any (deletion is terminal)
```

#### 12. Add Distributed Tracing

Integrate with OpenTelemetry or similar for operation tracing:

```bash
pipeline::start_span() {
  local operation="$1"
  local trace_id
  trace_id=$(uuidgen)

  export KUBEXM_TRACE_ID="${trace_id}"
  export KUBEXM_SPAN_START="$(date +%s)"

  logger::info "[TRACE:${trace_id}] Starting ${operation}"
}

pipeline::end_span() {
  local status="$1"
  local duration=$(( $(date +%s) - KUBEXM_SPAN_START ))

  logger::info "[TRACE:${KUBEXM_TRACE_ID}] Completed with status=${status} duration=${duration}s"

  # Could send to tracing backend here
}
```

#### 13. Implement Event Sourcing

Log all state-changing operations for audit trail:

```bash
pipeline::emit_event() {
  local event_type="$1"
  local details="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local event_log="${KUBEXM_DATA_DIR}/${KUBEXM_CLUSTER_NAME}/events.log"
  echo "${timestamp} ${event_type} ${details}" >> "${event_log}"
}

# Usage:
# pipeline::emit_event "CLUSTER.UPGRADE.START" "from=v1.27.0 to=v1.28.0"
# pipeline::emit_event "CLUSTER.UPGRADE.COMPLETE" "status=success"
```

---

## Summary Statistics

### Pipeline Inventory

| Category | Count | Files |
|----------|-------|-------|
| Cluster Lifecycle | 14 | create, delete, scale-out, scale-in, upgrade (x2), backup, restore, health, reconfigure, renew (x4) |
| Asset Management | 4 | download, push_images, manifests, iso |
| Registry | 2 | create_registry, delete_registry |
| **Total** | **20** | - |

### Safety Feature Coverage

| Feature | Implemented | Coverage |
|---------|-------------|----------|
| Timeout Watchdog | ✅ | 100% (critical ops) |
| Cluster Locking | ✅ | 100% (write ops) |
| Dry-Run Support | ✅ | 100% |
| Rollback Mechanism | ❌ | 5% (only create_cluster) |
| Pre-Operation Backup | ⚠️ | 10% (upgrades, soft-fail) |
| Post-Operation Validation | ❌ | 5% (only smoke test in create) |
| Interactive Confirmation | ✅ | 10% (delete, restore) |
| Progress Tracking | ❌ | 5% (only create_cluster) |
| Quorum Checks | ❌ | 0% |
| Resource Validation | ❌ | 0% |
| Retry Logic | ❌ | 0% |
| Circuit Breaker | ❌ | 0% |

### Code Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Total Pipeline Lines | ~2500 | - |
| Average Pipeline Size | 125 lines | ✅ Good |
| Largest Pipeline | create_cluster (209 lines) | ⚠️  Could be split |
| Smallest Pipeline | manifests (16 lines) | ✅ Simple |
| Functions per Pipeline | 5-10 | ✅ Well-structured |
| Error Handling Patterns | Inconsistent | ❌ Needs standardization |

---

## Conclusion

The kubexm-script pipeline framework provides a solid foundation for cluster lifecycle management with good separation of concerns and consistent patterns. However, several critical gaps must be addressed before production deployment:

1. **Immediate**: Fix missing `pipeline::scale_cluster` function
2. **Critical**: Implement rollback mechanisms for all destructive operations
3. **High**: Add pre-operation backups and quorum checks
4. **Medium**: Implement retry logic and post-operation validation
5. **Long-term**: Add state machine, distributed tracing, and event sourcing

With these improvements, the pipeline framework will achieve production-grade reliability and operational safety.

---

**Report Generated**: 2026-04-15
**Next Review**: After implementing critical fixes
