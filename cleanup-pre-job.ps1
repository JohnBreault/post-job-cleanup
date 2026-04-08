# Pre-job cleanup script for Windows Server GHES self-hosted runner
# Cleans the _work directory to remove leftover files from previous Actions runs,
# while preserving the _tool cache.
#
# Usage: Configure ACTIONS_RUNNER_HOOK_JOB_STARTED in the runner's .env file
# See: https://docs.github.com/en/enterprise-server@3.20/actions/how-tos/manage-runners/self-hosted-runners/run-scripts

$WorkDir = "C:\actions-runner\_work"
$PreserveDir = "_tool"

Write-Output "[cleanup-pre-job] Starting pre-job cleanup..."

if (-not (Test-Path -Path $WorkDir)) {
    Write-Output "[cleanup-pre-job] Work directory does not exist: $WorkDir — nothing to clean."
    exit 0
}

Write-Output "[cleanup-pre-job] Cleaning contents of: $WorkDir (preserving $PreserveDir)"

try {
    $items = Get-ChildItem -Path $WorkDir -Force

    foreach ($item in $items) {
        if ($item.Name -eq $PreserveDir) {
            Write-Output "[cleanup-pre-job] Preserving: $($item.FullName)"
            continue
        }
        Write-Output "[cleanup-pre-job] Removing: $($item.FullName)"
        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
    }

    Write-Output "[cleanup-pre-job] File cleanup complete."

    # Prune all unused Docker data (images, containers, volumes, networks)
    # Wrap with a timeout to prevent blocking job execution indefinitely.
    $DockerTimeout = 300
    Write-Output "[cleanup-pre-job] Pruning Docker system (timeout: ${DockerTimeout}s)..."
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerJob = Start-Job -ScriptBlock { docker system prune -a --volumes --force 2>&1 }
        $completed = $dockerJob | Wait-Job -Timeout $DockerTimeout
        if ($completed) {
            Receive-Job -Job $dockerJob
            if ($dockerJob.State -eq 'Completed') {
                Write-Output "[cleanup-pre-job] Docker prune complete."
            }
            else {
                Write-Output "[cleanup-pre-job] Docker prune failed, continuing anyway."
            }
        }
        else {
            Stop-Job -Job $dockerJob
            Write-Output "[cleanup-pre-job] Docker prune timed out after ${DockerTimeout}s, continuing anyway."
        }
        Remove-Job -Job $dockerJob -Force
    }
    else {
        Write-Output "[cleanup-pre-job] Docker not found, skipping prune."
    }

    Write-Output "[cleanup-pre-job] Cleanup complete."
    exit 0
}
catch {
    Write-Error "[cleanup-pre-job] Error during cleanup: $_"
    exit 1
}
