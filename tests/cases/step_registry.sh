#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KUBEXM_ROOT="${ROOT}"
source "${ROOT}/internal/step/lib/registry.sh"
source "${ROOT}/internal/runner/runner.sh"

# ---- Bug fix: step::register_dir underscore→dot conversion ----
# cluster_render_runtime_docker.sh → cluster.render.runtime.docker (NOT cluster.render_runtime_docker)
# This tests the underscore→dot conversion in step::register_dir

# Create a temp dir with a known step file
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

# Simulate a nested step: cluster_render_runtime_docker.sh
cat > "${TMPDIR}/cluster_render_runtime_docker.sh" << 'NOP'
#!/usr/bin/env bash
echo "dummy step"
NOP

# Register via register_dir (group=cluster, file=cluster_render_runtime_docker.sh)
step::register_dir "cluster" "${TMPDIR}"

# The expected key is "cluster.render.runtime.docker" (all underscores → dots)
# Without the fix, it would be "cluster.render_runtime_docker" (only first underscore → dot)
if [[ -z "${KUBEXM_STEP_REGISTRY[cluster.render.runtime.docker]+_}" ]]; then
  echo "FAIL: cluster.render.runtime.docker not registered (underscore→dot conversion broken)" >&2
  echo "  Available keys:" >&2
  for k in "${!KUBEXM_STEP_REGISTRY[@]}"; do echo "    $k" >&2; done
  exit 1
fi

# Also verify the step file path matches
if [[ "${KUBEXM_STEP_REGISTRY[cluster.render.runtime.docker]}" != "${TMPDIR}/cluster_render_runtime_docker.sh" ]]; then
  echo "FAIL: cluster.render.runtime.docker path mismatch" >&2
  exit 1
fi

# ---- Bug fix: missing directory registrations in step::register_all ----
# runtime, cni, addons, os dirs were not registered
# Verify the directories exist (they should be part of the codebase)
if [[ ! -d "${ROOT}/internal/step/runtime" ]]; then
  echo "FAIL: internal/step/runtime directory does not exist" >&2
  exit 1
fi
if [[ ! -d "${ROOT}/internal/step/network/cni" ]]; then
  echo "FAIL: internal/step/network/cni directory does not exist" >&2
  exit 1
fi
if [[ ! -d "${ROOT}/internal/step/addons" ]]; then
  echo "FAIL: internal/step/addons directory does not exist" >&2
  exit 1
fi
if [[ ! -d "${ROOT}/internal/step/os" ]]; then
  echo "FAIL: internal/step/os directory does not exist" >&2
  exit 1
fi

# step::register_all should register these directories
KUBEXM_STEP_REGISTRY=()  # reset
step::register_all

# Check that runtime steps are registered (at least one)
has_runtime=0
for key in "${!KUBEXM_STEP_REGISTRY[@]}"; do
  if [[ "${key}" == runtime.* ]]; then
    has_runtime=1
    break
  fi
done
if [[ ${has_runtime} -eq 0 ]]; then
  echo "FAIL: no runtime.* steps registered by step::register_all" >&2
  exit 1
fi

# Check that os steps are registered (at least one)
has_os=0
for key in "${!KUBEXM_STEP_REGISTRY[@]}"; do
  if [[ "${key}" == os.* ]]; then
    has_os=1
    break
  fi
done
if [[ ${has_os} -eq 0 ]]; then
  echo "FAIL: no os.* steps registered by step::register_all" >&2
  exit 1
fi

# ---- Original test: register + load a known step ----
step::register "check.os" "${ROOT}/internal/step/common/checks/check_os.sh"
step::load "check.os"
step::check.os::check >/dev/null
