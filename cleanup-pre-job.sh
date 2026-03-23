#!/bin/bash
# Pre-job cleanup script for Ubuntu GHES self-hosted runner
# Cleans the _work directory to remove leftover files from previous Actions runs,
# while preserving the _tool cache.
#
# Usage: Configure ACTIONS_RUNNER_HOOK_JOB_STARTED in the runner's .env file
# See: https://docs.github.com/en/enterprise-server@3.19/actions/how-tos/manage-runners/self-hosted-runners/run-scripts

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
    rm -rf "$item"
done

# Also clean hidden files/directories (e.g. .dotfiles)
for item in "$WORK_DIR"/.[!.]*; do
    [ -e "$item" ] || continue
    echo "[cleanup-pre-job] Removing hidden item: $item"
    rm -rf "$item"
done

echo "[cleanup-pre-job] Cleanup complete."
exit 0
