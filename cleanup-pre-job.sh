#!/bin/bash
# Pre-job cleanup script for Ubuntu GHES self-hosted runner
# Cleans the _work directory to remove leftover files from previous Actions runs,
# while preserving the _tool cache.
#
# Usage: Configure ACTIONS_RUNNER_HOOK_JOB_STARTED in the runner's .env file
# See: https://docs.github.com/en/enterprise-server@3.20/actions/how-tos/manage-runners/self-hosted-runners/run-scripts
#
# NOTE: The runner executes bash scripts with -e (errexit). Any command that
#       fails will abort the script and mark the job as failed. Guard fallible
#       commands with "|| true" to allow the job to continue.

WORK_DIR="/actions-runner/_work"
PRESERVE_DIR="_tool"

echo "[cleanup-pre-job] Starting pre-job cleanup..."

if [ ! -d "$WORK_DIR" ]; then
    echo "[cleanup-pre-job] Work directory does not exist: $WORK_DIR — nothing to clean."
    exit 0
fi

echo "[cleanup-pre-job] Cleaning contents of: $WORK_DIR (preserving $PRESERVE_DIR)"

# Remove all items in _work except the _tool cache directory
for item in "$WORK_DIR"/*; do
    [ -e "$item" ] || continue
    basename="$(basename "$item")"
    if [ "$basename" = "$PRESERVE_DIR" ]; then
        echo "[cleanup-pre-job] Preserving: $item"
        continue
    fi
    echo "[cleanup-pre-job] Removing: $item"
    rm -rf "$item" || true
done

# Also clean hidden files/directories (e.g. .dotfiles)
for item in "$WORK_DIR"/.[!.]*; do
    [ -e "$item" ] || continue
    echo "[cleanup-pre-job] Removing hidden item: $item"
    rm -rf "$item" || true
done

echo "[cleanup-pre-job] File cleanup complete."

# Prune all unused Docker data (images, containers, volumes, networks)
# Wrap with timeout to prevent blocking job execution indefinitely.
DOCKER_TIMEOUT=300
echo "[cleanup-pre-job] Pruning Docker system (timeout: ${DOCKER_TIMEOUT}s)..."
if command -v docker &> /dev/null; then
    if timeout "$DOCKER_TIMEOUT" docker system prune -a --volumes --force; then
        echo "[cleanup-pre-job] Docker prune complete."
    else
        echo "[cleanup-pre-job] Docker prune failed or timed out (exit code $?), continuing anyway."
    fi
else
    echo "[cleanup-pre-job] Docker not found, skipping prune."
fi

echo "[cleanup-pre-job] Cleanup complete."
exit 0
