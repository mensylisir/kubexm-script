# ==============================================================================
# KubeXM Script - Makefile
# ==============================================================================

.PHONY: help clean set-permissions install lint install-hooks test

help:
	@echo "KubeXM Script - Kubernetes集群部署和管理工具"
	@echo ""
	@echo "常用命令:"
	@echo "  bin/kubexm download --cluster=<name>"
	@echo "  bin/kubexm create cluster --cluster=<name>"
	@echo "  bin/kubexm delete cluster --cluster=<name>"
	@echo "  bin/kubexm scale cluster --cluster=<name> --action=scale-out|scale-in"
	@echo "  bin/kubexm upgrade cluster --cluster=<name> --to-version=<ver>"
	@echo "  bin/kubexm upgrade etcd --cluster=<name> --to-version=<ver>"
	@echo "  bin/kubexm create iso [--with-build-*]"
	@echo "  bin/kubexm manifests [--cluster=<name>]"
	@echo ""
	@echo "辅助目标:"
	@echo "  make clean"
	@echo "  make set-permissions"
	@echo "  make lint"
	@echo "  make install-hooks"
	@echo "  make test"

clean:
	@rm -rf build/*
	@echo "Build directory cleaned"

# ==============================================================================
# Linting: run shellcheck + architecture/step structure checks
# ==============================================================================
lint:
	@echo "=== Running shellcheck ==="
	@which shellcheck >/dev/null 2>&1 || { echo "shellcheck not found. Install: apt-get install shellcheck"; exit 1; }
	@shellcheck --rcfile=.shellcheckrc \
		--external-sources \
		--severity=error \
		--format=gcc \
		internal/**/*.sh bin/* scripts/*.sh 2>&1 || { echo "Shellcheck FAILED"; exit 1; }
	@echo "=== Shellcheck passed ==="
	@echo "=== Running architecture and Step structure checks ==="
	@KUBEXM_ROOT="$$(pwd)" bash scripts/lint-step-structure.sh || { echo "Architecture lint FAILED"; exit 1; }
	@echo "=== All checks passed ==="

# ==============================================================================
# Pre-commit hook installation
# ==============================================================================
install-hooks:
	@ln -sf ../../.git/hooks/pre-commit .git/hooks/pre-commit 2>/dev/null || \
		cp .git/hooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed"

test:
	@bash tests/run-tests.sh

set-permissions:
	@chmod +x bin/kubexm
	@find internal/utils/resources -name "*.sh" -exec chmod +x {} \;
	@chmod +x templates/install/install.sh
	@echo "Permissions set"

install: set-permissions
	@echo "KubeXM Script installed successfully"
	@echo "Usage: bin/kubexm --help"
