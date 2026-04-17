# KubeXM Command Trace Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all code issues listed in `docs/kubexm-command-trace-report.md` by aligning CLI/phase behavior, configuration parsing, safety checks, and create-iso semantics.

**Architecture:** Apply targeted fixes grouped by subsystem (CLI/phase parity, config parsing, registry/push, create-iso, safety/validation). Keep changes minimal and localized to existing entrypoints and phases. Ensure each fix is traceable to a specific ledger item (A1–A93) and does not introduce new behaviors beyond the intended correction.

**Tech Stack:** Bash scripts, existing KubeXM shell libs (lib/**, internal/step/legacy/phases/**), repo tests (tests/run-tests.sh if present).

---

## Chunk 1: CLI/Phase Parity + Config Parsing Consistency

### Task 1: Align upgrade cluster CLI/phase parameters and behavior

**Files:**
- Modify: `bin/kubexm:1218-1281`
- Modify: `internal/step/legacy/phases/cluster/upgrade-cluster.sh:22-347`

- [ ] **Step 1: Write the failing test (shell check)**

```bash
# (If no existing tests for this behavior, record a manual repro in notes)
# Example manual check: ensure --to-version is accepted by phase entry when invoked.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: (if relevant tests exist) FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Make phase `upgrade-cluster.sh` accept `--to-version` in its `main()` parser (in addition to `--version`) or align CLI to call phase with `--version` consistently.
- Ensure phase uses parsed config/hosts if it accesses `config::get_*` (add `config::parse_config` / `config::parse_hosts` at phase entry or require CLI to pass pre-parsed context).

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage if no tests exist).

- [ ] **Step 5: Commit**

```bash
git add bin/kubexm internal/step/legacy/phases/cluster/upgrade-cluster.sh
git commit -m "fix: align upgrade cluster cli and phase params"
```

### Task 2: Align upgrade etcd CLI/phase parameters and config parsing

**Files:**
- Modify: `internal/step/legacy/phases/cluster/upgrade-etcd.sh:23-86`
- Modify (if needed): `bin/kubexm:1287-1350`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure upgrade-etcd phase reads config/hosts before using role members.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Add `config::parse_config` / `config::parse_hosts` within `phases::upgrade_etcd` before role lookups, or assert caller did it and fail with explicit error if not.
- If `etcd_type=exists`, block or prompt for manual upgrade path before calling `etcd::backup` (matches ledger A85).

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add internal/step/legacy/phases/cluster/upgrade-etcd.sh bin/kubexm
git commit -m "fix: parse config in upgrade etcd phase"
```

### Task 3: Fix renew-certs parsing + deploy_type injection

**Files:**
- Modify: `internal/step/legacy/phases/certificates/renew-certs.sh:32-115`
- Modify: `bin/kubexm:1751-1808`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure renew-certs reads config/hosts and sets deploy_type from config.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Add `config::parse_config` / `config::parse_hosts` before role lookups in renew-certs phase.
- In CLI entry, export `KUBEXM_KUBERNETES_TYPE` from config getter.
- Optionally expose `--phase` to map to `KUBEXM_ROTATION_PHASE` (ledger A51/A67).

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add bin/kubexm internal/step/legacy/phases/certificates/renew-certs.sh
git commit -m "fix: renew certs config parsing and phase options"
```

---

## Chunk 2: Registry + Push Safety and Option Parity

### Task 4: Registry CLI ↔ phase option parity

**Files:**
- Modify: `bin/kubexm:472-546`
- Modify: `internal/step/legacy/phases/registry/delete-registry.sh:22-140`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure delete registry CLI exposes --delete-images and --local.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Add `--delete-images` and `--local` to CLI parsing and forward into phase.
- Ensure help text and usage strings match exposed options.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add bin/kubexm internal/step/legacy/phases/registry/delete-registry.sh
git commit -m "fix: align delete registry cli and phase options"
```

### Task 5: Registry config path consistency

**Files:**
- Modify: `internal/step/legacy/phases/registry/create-registry.sh:58-66`
- Modify: `internal/step/legacy/phases/registry/delete-registry.sh:178`
- Modify: `lib/registry/registry.sh:90-104,160-163`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure registry.enable and data_dir read from spec.registry.* consistently.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Standardize registry config keys to `spec.registry.*` within all phases and lib usage.
- Add mapping only if necessary for backward compatibility.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add internal/step/legacy/phases/registry/create-registry.sh internal/step/legacy/phases/registry/delete-registry.sh lib/registry/registry.sh
git commit -m "fix: normalize registry config paths"
```

### Task 6: Remove eval usage in push scripts

**Files:**
- Modify: `lib/registry/push.sh:80-330,498-651`
- Modify: `lib/registry/push_optimized.sh:98`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure manifest and copy commands run without eval.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Replace eval with arrays or direct command invocation.
- Ensure arguments are properly quoted and do not change behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add lib/registry/push.sh lib/registry/push_optimized.sh
git commit -m "fix: remove eval from image push commands"
```

### Task 7: Add xmjq/xmyq dependency checks

**Files:**
- Modify: `bin/kubexm:918-924`
- Modify: `lib/registry/push_optimized.sh:128-143`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure missing xmjq/xmyq yields explicit error.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Add explicit `command -v` checks or file existence checks before calling xmjq/xmyq.
- Provide clear error message and exit code.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add bin/kubexm lib/registry/push_optimized.sh
git commit -m "fix: check xmjq/xmyq dependencies"
```

---

## Chunk 3: Create ISO Semantics + Scale/LB Safety

### Task 8: Restrict create iso to system packages only

**Files:**
- Modify: `bin/kubexm:293-343`
- Modify: `internal/step/legacy/phases/resources/download.sh:256-372,487-511`
- Modify: `internal/step/legacy/phases/build/build-system-packages-iso.sh` (if needed)

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure create iso does not download Kubernetes images/binaries.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Split `download_all` to support an `iso-build` mode that only builds system package ISO.
- Ensure `--with-build-local` is honored in ISO build path.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add bin/kubexm internal/step/legacy/phases/resources/download.sh internal/step/legacy/phases/build/build-system-packages-iso.sh
git commit -m "fix: limit create iso to system packages"
```

### Task 9: Scale cluster LB update coverage + safety checks

**Files:**
- Modify: `internal/step/legacy/phases/cluster/scale-cluster.sh:25-310`
- Modify: `lib/loadbalancer/loadbalancer.sh:260-345`

- [ ] **Step 1: Write failing test (manual repro notes)**

```bash
# Ensure external lb types (kubexm-kh/kn) are handled.
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run-tests.sh`
Expected: FAIL or note missing coverage.

- [ ] **Step 3: Implement minimal fix**

- Add handling for external lb types or normalize lb_type before switch.
- Add dependency checks for kubeadm/kubectl/ssh at entry.

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 5: Commit**

```bash
git add internal/step/legacy/phases/cluster/scale-cluster.sh lib/loadbalancer/loadbalancer.sh
git commit -m "fix: scale cluster lb update and prereq checks"
```

---

## Chunk 4: Validation + Documentation Alignment

### Task 10: Re-run and reconcile remaining ledger items

**Files:**
- Modify: `docs/kubexm-command-trace-report.md` (if needed for evidence updates)

- [ ] **Step 1: Audit remaining ledger items**

- Cross-check any unresolved items in the report against code changes.

- [ ] **Step 2: Update report evidence**

- Ensure new line references match the updated code after fixes.

- [ ] **Step 3: Run tests**

Run: `tests/run-tests.sh`
Expected: PASS (or note missing coverage).

- [ ] **Step 4: Commit**

```bash
git add docs/kubexm-command-trace-report.md
git commit -m "docs: update evidence after code fixes"
```
