# Post-job cleanup script for Windows Server GHES self-hosted runner
# Cleans the _work directory to remove leftover files from previous Actions runs,
# while preserving the _tool cache.
#
# Usage: Configure ACTIONS_RUNNER_HOOK_JOB_COMPLETED in the runner's .env file
# See: https://docs.github.com/en/enterprise-server@3.20/actions/how-tos/manage-runners/self-hosted-runners/run-scripts

$WorkDir = "C:\actions-runner\_work"
$PreserveDir = "_tool"

Write-Output "[cleanup-post-job] Starting post-job cleanup..."

if (-not (Test-Path -Path $WorkDir)) {
    Write-Output "[cleanup-post-job] Work directory does not exist: $WorkDir — nothing to clean."
    exit 0
}

Write-Output "[cleanup-post-job] Cleaning contents of: $WorkDir (preserving $PreserveDir)"

try {
    $items = Get-ChildItem -Path $WorkDir -Force

    foreach ($item in $items) {
        if ($item.Name -eq $PreserveDir) {
            Write-Output "[cleanup-post-job] Preserving: $($item.FullName)"
            continue
        }
        Write-Output "[cleanup-post-job] Removing: $($item.FullName)"
        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
    }

    Write-Output "[cleanup-post-job] File cleanup complete."

    # Clean TEMP directory to remove temporary files left by the workflow
    $TempDir = $env:TEMP
    if ($TempDir -and (Test-Path -Path $TempDir)) {
        Write-Output "[cleanup-post-job] Cleaning TEMP directory: $TempDir"
        $tempItems = Get-ChildItem -Path $TempDir -Force -ErrorAction SilentlyContinue
        foreach ($tempItem in $tempItems) {
            Write-Output "[cleanup-post-job] Removing temp item: $($tempItem.FullName)"
            Remove-Item -Path $tempItem.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Output "[cleanup-post-job] TEMP cleanup complete."
    }

    # Clean user home directory caches that workflows and package managers leave behind
    $RunnerHome = $env:USERPROFILE
    $CacheDirs = @(".npm", ".nuget", ".cache", ".m2", ".gradle", ".cargo", ".rustup", ".dotnet",
                    "AppData\Local\NuGet", "AppData\Local\pip")
    Write-Output "[cleanup-post-job] Cleaning user caches in $RunnerHome..."
    foreach ($cache in $CacheDirs) {
        $target = Join-Path -Path $RunnerHome -ChildPath $cache
        if (Test-Path -Path $target) {
            Write-Output "[cleanup-post-job] Removing cache: $target"
            Remove-Item -Path $target -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Output "[cleanup-post-job] User cache cleanup complete."

    # Prune all unused Docker data (images, containers, volumes, networks)
    # Wrap with a timeout to prevent blocking job execution indefinitely.
    $DockerTimeout = 300
    Write-Output "[cleanup-post-job] Pruning Docker system (timeout: ${DockerTimeout}s)..."
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerJob = Start-Job -ScriptBlock { docker system prune -a --volumes --force 2>&1 }
        $completed = $dockerJob | Wait-Job -Timeout $DockerTimeout
        if ($completed) {
            Receive-Job -Job $dockerJob
            if ($dockerJob.State -eq 'Completed') {
                Write-Output "[cleanup-post-job] Docker prune complete."
            }
            else {
                Write-Output "[cleanup-post-job] Docker prune failed, continuing anyway."
            }
        }
        else {
            Stop-Job -Job $dockerJob
            Write-Output "[cleanup-post-job] Docker prune timed out after ${DockerTimeout}s, continuing anyway."
        }
        Remove-Job -Job $dockerJob -Force
    }
    else {
        Write-Output "[cleanup-post-job] Docker not found, skipping prune."
    }

    Write-Output "[cleanup-post-job] Cleanup complete."
    exit 0
}
catch {
    Write-Error "[cleanup-post-job] Error during cleanup: $_"
    exit 1
}
