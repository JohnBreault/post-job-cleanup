# Pre-job cleanup script for Windows Server GHES self-hosted runner
# Cleans the _work directory to remove leftover files from previous Actions runs,
# while preserving the _tool cache.
#
# Usage: Configure ACTIONS_RUNNER_HOOK_JOB_STARTED in the runner's .env file
# See: https://docs.github.com/en/enterprise-server@3.19/actions/how-tos/manage-runners/self-hosted-runners/run-scripts

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

    Write-Output "[cleanup-pre-job] Cleanup complete."
    exit 0
}
catch {
    Write-Error "[cleanup-pre-job] Error during cleanup: $_"
    exit 1
}
