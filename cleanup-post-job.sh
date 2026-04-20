#!/bin/bash
# Post-job cleanup script for Ubuntu GHES self-hosted runner
# Cleans the _work directory to remove leftover files from previous Actions runs,
# while preserving the _tool cache.
#
# Usage: Configure ACTIONS_RUNNER_HOOK_JOB_COMPLETED in the runner's .env file
# See: https://docs.github.com/en/enterprise-server@3.20/actions/how-tos/manage-runners/self-hosted-runners/run-scripts
#
# NOTE: The runner executes bash scripts with -e (errexit). Any command that
#       fails will abort the script and mark the job as failed. Guard fallible
#       commands with "|| true" to allow the job to continue.

WORK_DIR="/actions-runner/_work"
PRESERVE_DIR="_tool"

echo "[cleanup-post-job] Starting post-job cleanup..."

if [ ! -d "$WORK_DIR" ]; then
    echo "[cleanup-post-job] Work directory does not exist: $WORK_DIR — nothing to clean."
    exit 0
fi

echo "[cleanup-post-job] Cleaning contents of: $WORK_DIR (preserving $PRESERVE_DIR)"

# Remove all items in _work except the _tool cache directory
for item in "$WORK_DIR"/*; do
    [ -e "$item" ] || continue
    basename="$(basename "$item")"
    if [ "$basename" = "$PRESERVE_DIR" ]; then
        echo "[cleanup-post-job] Preserving: $item"
        continue
    fi
    echo "[cleanup-post-job] Removing: $item"
    rm -rf "$item" || true
done

# Also clean hidden files/directories (e.g. .dotfiles)
for item in "$WORK_DIR"/.[!.]*; do
    [ -e "$item" ] || continue
    echo "[cleanup-post-job] Removing hidden item: $item"
    rm -rf "$item" || true
done

echo "[cleanup-post-job] File cleanup complete."

# Clean /tmp to remove temporary files left by the workflow
echo "[cleanup-post-job] Cleaning /tmp..."
for item in /tmp/*; do
    [ -e "$item" ] || continue
    echo "[cleanup-post-job] Removing tmp item: $item"
    rm -rf "$item" || true
done
for item in /tmp/.[!.]*; do
    [ -e "$item" ] || continue
    echo "[cleanup-post-job] Removing hidden tmp item: $item"
    rm -rf "$item" || true
done
echo "[cleanup-post-job] /tmp cleanup complete."

# Clean user home directory caches that workflows and package managers leave behind
RUNNER_HOME="${HOME:-/home/runner}"
CACHE_DIRS=(".npm" ".nuget" ".cache" ".local/share/NuGet" ".m2" ".gradle" ".cargo" ".rustup" ".dotnet")
echo "[cleanup-post-job] Cleaning user caches in $RUNNER_HOME..."
for cache in "${CACHE_DIRS[@]}"; do
    target="$RUNNER_HOME/$cache"
    if [ -d "$target" ]; then
        echo "[cleanup-post-job] Removing cache: $target"
        rm -rf "$target" || true
    fi
done
echo "[cleanup-post-job] User cache cleanup complete."

# Prune all unused Docker data (images, containers, volumes, networks)
# Wrap with timeout to prevent blocking job execution indefinitely.
DOCKER_TIMEOUT=300
echo "[cleanup-post-job] Pruning Docker system (timeout: ${DOCKER_TIMEOUT}s)..."
if command -v docker &> /dev/null; then
    if timeout "$DOCKER_TIMEOUT" docker system prune -a --volumes --force; then
        echo "[cleanup-post-job] Docker prune complete."
    else
        echo "[cleanup-post-job] Docker prune failed or timed out (exit code $?), continuing anyway."
    fi
else
    echo "[cleanup-post-job] Docker not found, skipping prune."
fi

echo "[cleanup-post-job] Cleanup complete."
exit 0
