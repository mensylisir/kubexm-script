#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/lint-step-structure.sh"

make_fixture() {
  local dir="$1"
  mkdir -p "${dir}/internal/context" "${dir}/internal/step/sample" "${dir}/internal/task" "${dir}/internal/runner"
  cat > "${dir}/internal/context/context.sh" <<'EOF'
context::get() { return 0; }
EOF
  cat > "${dir}/internal/task/common.sh" <<'EOF'
task::noop() { return 0; }
EOF
  cat > "${dir}/internal/runner/runner.sh" <<'EOF'
runner::exec() { return 0; }
EOF
}

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

valid_root="${TMPDIR}/valid"
invalid_step_task_root="${TMPDIR}/invalid-step-task"
invalid_pipeline_task_root="${TMPDIR}/invalid-pipeline-task"

make_fixture "${valid_root}"
make_fixture "${invalid_step_task_root}"
make_fixture "${invalid_pipeline_task_root}"
mkdir -p "${invalid_pipeline_task_root}/internal/pipeline"

cat > "${valid_root}/internal/step/sample/valid_step.sh" <<'EOF'
#!/usr/bin/env bash
source "${KUBEXM_ROOT}/internal/runner/runner.sh"
step::sample.valid::run() { return 0; }
step::sample.valid::check() { return 0; }
step::sample.valid::rollback() { return 0; }
EOF

cat > "${invalid_step_task_root}/internal/step/sample/invalid_step.sh" <<'EOF'
#!/usr/bin/env bash
source "${KUBEXM_ROOT}/internal/task/common.sh"
step::sample.invalid::run() { return 0; }
step::sample.invalid::check() { return 0; }
step::sample.invalid::rollback() { return 0; }
EOF

cat > "${invalid_pipeline_task_root}/internal/pipeline/invalid_pipeline.sh" <<'EOF'
#!/usr/bin/env bash
# Pipeline sourcing a non-allowed task file (not common.sh or cluster/) - this is the invalid case
source "${KUBEXM_ROOT}/internal/task/infra/system_check/main.sh"
pipeline::invalid() { task::noop; }
EOF

if ! KUBEXM_ROOT="${valid_root}" bash "${SCRIPT}" >/dev/null 2>&1; then
  echo "FAIL: valid fixture should pass architecture lint" >&2
  exit 1
fi

if KUBEXM_ROOT="${invalid_step_task_root}" bash "${SCRIPT}" >/tmp/arch-invalid-step.log 2>&1; then
  echo "FAIL: invalid step fixture should fail architecture lint" >&2
  exit 1
fi
if ! grep -q "step sources task layer directly" /tmp/arch-invalid-step.log; then
  echo "FAIL: invalid step fixture did not report step->task violation" >&2
  cat /tmp/arch-invalid-step.log >&2
  exit 1
fi

if KUBEXM_ROOT="${invalid_pipeline_task_root}" bash "${SCRIPT}" >/tmp/arch-invalid-pipeline.log 2>&1; then
  echo "FAIL: invalid pipeline fixture should fail architecture lint" >&2
  exit 1
fi
if ! grep -q "pipeline sources non-module internal layer" /tmp/arch-invalid-pipeline.log; then
  echo "FAIL: invalid pipeline fixture did not report pipeline violation" >&2
  cat /tmp/arch-invalid-pipeline.log >&2
  exit 1
fi
