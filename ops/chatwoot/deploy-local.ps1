[CmdletBinding()]
param(
    [string]$Server = "192.168.116.123",
    [string]$SshUser = "root",
    [int]$SshPort = 22,
    [string]$SshKey = "$env:USERPROFILE\.ssh\id_ed25519_vm100",
    [switch]$NoCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE"
    }
}

function Invoke-NativeCapture([string]$Command, [string[]]$Arguments) {
    $output = & $Command @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed: $($output -join [Environment]::NewLine)"
    }
    return (($output | Select-Object -Last 1).ToString()).Trim()
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$timestamp = [DateTime]::UtcNow.ToString("yyyyMMddHHmmss")
$revision = Invoke-NativeCapture "git" @("-C", $root, "rev-parse", "--short=12", "HEAD")
$imageTag = "local-$revision-$timestamp"
$image = "vibecraft/chatwoot:$imageTag"
$batch = Join-Path ([IO.Path]::GetTempPath()) ("chatwoot-local-" + [guid]::NewGuid().ToString("N"))
$imageArchive = Join-Path $batch "chatwoot.tar"
$compressedArchive = Join-Path $batch "chatwoot.tar.gz"
$readme = Join-Path $root "ops\chatwoot\README.md"
$remote = "$SshUser@$Server"
$remoteDir = "/tmp/chatwoot-local-$timestamp"
$remoteCompose = "/opt/chatwoot/docker-compose.production.yaml"
$remoteEnv = "/etc/chatwoot/chatwoot.env"
$sshArgs = @("-i", $SshKey, "-p", "$SshPort", "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes")
$scpArgs = @("-i", $SshKey, "-P", "$SshPort", "-o", "IdentitiesOnly=yes", "-o", "BatchMode=yes")

try {
    $releaseStarted = Get-Date
    if (-not (Test-Path -LiteralPath $SshKey)) {
        throw "SSH key not found: $SshKey"
    }
    if (-not (Test-Path -LiteralPath $readme)) {
        throw "Deployment README not found: $readme"
    }

    New-Item -ItemType Directory -Path $batch -Force | Out-Null

    Write-Host "Checking local Docker..."
    Invoke-Native "docker" @("info")

    $buildArgs = @(
        "build", "--platform", "linux/amd64", "-t", $image,
        "-f", (Join-Path $root "docker\Dockerfile"), $root
    )
    if ($NoCache) {
        $buildArgs = @(
            "build", "--no-cache", "--platform", "linux/amd64", "-t", $image,
            "-f", (Join-Path $root "docker\Dockerfile"), $root
        )
    }

    Write-Host "Building $image ..."
    $stageStarted = Get-Date
    Invoke-Native "docker" $buildArgs
    $buildSeconds = ((Get-Date) - $stageStarted).TotalSeconds

    $stageStarted = Get-Date
    Invoke-Native "docker" @("save", "-o", $imageArchive, $image)
    Invoke-Native "tar.exe" @("-czf", $compressedArchive, "-C", $batch, "chatwoot.tar")
    Remove-Item -LiteralPath $imageArchive -Force
    $archiveMegabytes = (Get-Item -LiteralPath $compressedArchive).Length / 1MB
    $packageSeconds = ((Get-Date) - $stageStarted).TotalSeconds

    Write-Host "Transferring image to $remote ..."
    $stageStarted = Get-Date
    Invoke-Native "ssh" ($sshArgs + @($remote, "mkdir -p '$remoteDir'"))
    Invoke-Native "scp" ($scpArgs + @($compressedArchive, $readme, ($remote + ":" + $remoteDir + "/")))
    $transferSeconds = ((Get-Date) - $stageStarted).TotalSeconds

    $remoteScript = @'
set -eu
compose_file='__REMOTE_COMPOSE__'
backup_file=$(printf '%s.bak-%s' "$compose_file" '__IMAGE_TAG__')
tmp_dir='__REMOTE_DIR__'
image='__IMAGE__'

test -r '__REMOTE_ENV__'
test -r "$compose_file"
cp -p "$compose_file" "$backup_file"
tar -xzf "$tmp_dir/chatwoot.tar.gz" -C "$tmp_dir"
docker load < "$tmp_dir/chatwoot.tar"

sed -i -E "0,/^[[:space:]]+image: vibecraft\\/chatwoot:.*/s#^[[:space:]]+image:.*#    image: $image#" "$compose_file"
docker-compose --env-file '__REMOTE_ENV__' -f "$compose_file" up -d rails sidekiq

ready=0
for attempt in $(seq 1 90); do
  if curl --fail --silent --max-time 5 http://127.0.0.1:3000/health >/dev/null; then
    ready=1
    break
  fi
  sleep 2
done

if [ "$ready" -ne 1 ]; then
  cp -p "$backup_file" "$compose_file"
  docker-compose --env-file '__REMOTE_ENV__' -f "$compose_file" up -d rails sidekiq || true
  docker-compose --env-file '__REMOTE_ENV__' -f "$compose_file" logs --tail=100 rails sidekiq || true
  rm -rf "$tmp_dir"
  exit 1
fi

install -m 0644 "$tmp_dir/README.md" /opt/chatwoot/README.md
docker-compose --env-file '__REMOTE_ENV__' -f "$compose_file" ps
docker inspect chatwoot-rails-1 --format 'running_image={{.Config.Image}}'
rm -rf "$tmp_dir"
'@
    $remoteScript = $remoteScript.Replace("__REMOTE_COMPOSE__", $remoteCompose)
    $remoteScript = $remoteScript.Replace("__REMOTE_ENV__", $remoteEnv)
    $remoteScript = $remoteScript.Replace("__REMOTE_DIR__", $remoteDir)
    $remoteScript = $remoteScript.Replace("__IMAGE_TAG__", $imageTag)
    $remoteScript = $remoteScript.Replace("__IMAGE__", $image)

    Write-Host "Rolling out $image ..."
    $stageStarted = Get-Date
    ($remoteScript -replace '\r\n', '\n') | & ssh @sshArgs $remote "sh"
    if ($LASTEXITCODE -ne 0) {
        throw "remote deployment failed with exit code $LASTEXITCODE"
    }
    $serverSeconds = ((Get-Date) - $stageStarted).TotalSeconds
    $totalSeconds = ((Get-Date) - $releaseStarted).TotalSeconds

    Write-Host "Chatwoot deployment completed: $image"
    Write-Host ("Timing: build={0:n1}s package={1:n1}s transfer={2:n1}s server={3:n1}s total={4:n1}s archive={5:n1}MB" -f $buildSeconds, $packageSeconds, $transferSeconds, $serverSeconds, $totalSeconds, $archiveMegabytes)
}
finally {
    if (Test-Path -LiteralPath $batch) {
        Remove-Item -LiteralPath $batch -Recurse -Force
    }
}
