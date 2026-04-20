# Post-Job Cleanup Scripts for GHES Self-Hosted Runners

Post-job scripts that automatically clean the `_work` directory on GitHub Enterprise Server (GHES) self-hosted runners after each job completes. This removes leftover files from the Actions run while preserving the tool cache.

| Script | OS | Runner Path |
|---|---|---|
| `cleanup-post-job.sh` | Ubuntu / Linux | `/actions-runner/_work/` |
| `cleanup-post-job.ps1` | Windows Server | `C:\actions-runner\_work\` |

## How It Works

These scripts hook into the [`ACTIONS_RUNNER_HOOK_JOB_COMPLETED`](https://docs.github.com/en/enterprise-server@3.20/actions/how-tos/manage-runners/self-hosted-runners/run-scripts) mechanism. When configured, the runner automatically executes the script after each job completes. The scripts:

1. Check if the `_work` directory exists
2. Remove all contents **except** the `_tool` cache directory
3. Clean temporary files (`/tmp` on Linux, `%TEMP%` on Windows)
4. Remove user home directory caches left by package managers (`.npm`, `.nuget`, `.cache`, `.m2`, `.gradle`, `.cargo`, `.rustup`, `.dotnet`, etc.)
5. Prune all unused Docker data (images, containers, volumes, networks)
6. Log each action for visibility in the "Complete runner" step logs
7. Exit with code `0` on success or non-zero on failure

## Deployment

### Ubuntu / Linux

1. **Copy the script** to the runner machine (outside the `actions-runner` directory):

   ```bash
   sudo mkdir -p /opt/runner-scripts
   sudo cp cleanup-post-job.sh /opt/runner-scripts/cleanup-post-job.sh
   ```

2. **Make it executable:**

   ```bash
   sudo chmod +x /opt/runner-scripts/cleanup-post-job.sh
   ```

3. **Configure the runner** by adding to the `.env` file in the runner's application directory (e.g., `/actions-runner/.env`):

   ```
   ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/opt/runner-scripts/cleanup-post-job.sh
   ```

4. **Restart the runner service** to pick up the `.env` change:

   ```bash
   sudo systemctl restart actions.runner.*.service
   ```

### Windows Server

1. **Copy the script** to the runner machine (outside the `actions-runner` directory):

   ```powershell
   New-Item -ItemType Directory -Path "C:\runner-scripts" -Force
   Copy-Item cleanup-post-job.ps1 -Destination "C:\runner-scripts\cleanup-post-job.ps1"
   ```

2. **Configure the runner** by adding to the `.env` file in the runner's application directory (e.g., `C:\actions-runner\.env`):

   ```
   ACTIONS_RUNNER_HOOK_JOB_COMPLETED=C:\runner-scripts\cleanup-post-job.ps1
   ```

3. **Restart the runner service** via Windows Services or:

   ```powershell
   Restart-Service actions.runner.*
   ```

## Verifying

After deploying, trigger a workflow run and check the job logs. The cleanup output will appear under the **"Complete runner"** step:

```
[cleanup-post-job] Starting post-job cleanup...
[cleanup-post-job] Cleaning contents of: /actions-runner/_work (preserving _tool)
[cleanup-post-job] Removing: /actions-runner/_work/my-repo
[cleanup-post-job] Cleanup complete.
```

## Troubleshooting

| Issue | Solution |
|---|---|
| **Permission denied** | Ensure the script is executable (`chmod +x` on Linux). Verify the runner service account has access to the script and the `_work` directory. |
| **Job fails immediately** | Check the "Complete runner" step logs. A non-zero exit code from the post-job script causes the job to fail. |
| **Script not running** | Verify the `.env` file path is correct and uses an absolute path. Restart the runner service after changes. |
| **Docker prune hangs** | Docker prune is wrapped in a 300-second timeout. Adjust `DOCKER_TIMEOUT` / `$DockerTimeout` if needed. |

## References

- [Running scripts before or after a job — GitHub Docs (GHES 3.20)](https://docs.github.com/en/enterprise-server@3.20/actions/how-tos/manage-runners/self-hosted-runners/run-scripts)
- [Variables reference — Default environment variables](https://docs.github.com/en/enterprise-server@3.20/actions/reference/variables-reference#default-environment-variables)
