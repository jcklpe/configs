#!/bin/bash
##- Set up the lifeos-tools Python environment: a uv-managed .venv built from
##- lifeos-tools/pyproject.toml + uv.lock. Idempotent; safe to re-run.

LIFEOS_TOOLS_DIR="${CONFIGS}/lifeos-tools"

if [ ! -f "${LIFEOS_TOOLS_DIR}/pyproject.toml" ]; then
    return 0 2>/dev/null || exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "uv not found — skipping lifeos-tools venv setup."
    echo "  Install uv, then run: (cd ${LIFEOS_TOOLS_DIR} && uv sync)"
    return 0 2>/dev/null || exit 0
fi

echo "Setting up lifeos-tools Python env (uv sync)..."
( cd "${LIFEOS_TOOLS_DIR}" && uv sync )
