# Sweep multiple model configurations through run_smoke_dlatest.ps1 in parallel.
#
# Same-model sweep:
#   $env:MODELS = "openai/gpt-oss-20b inclusionai/ling-2.6-1t:free"
#   powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest_sweep.ps1
#
# Per-role sweep:
#   $env:MODEL_RUNS = "attacker-model|defender-model|normal-user-model;attacker2|defender2|normal2"
#   powershell -ExecutionPolicy Bypass -File scripts/run_smoke_dlatest_sweep.ps1
#
# Parallel controls:
#   MAX_PARALLEL_MODELS  Number of model runs active at once. Default: 2.
#   FIRST_PORT_OFFSET    First run adds this offset to ports 9010/9020/9021/9022. Default: 100.
#   PORT_STEP            Offset step for each additional parallel run. Default: 100.
#   LOG_POLL_SECONDS     Seconds between intermediate log flushes. Default: 5.
#
# Other env vars are passed through to run_smoke_dlatest.ps1:
#   SCENARIOS, REPS, SHOW_LOGS, STARTUP_TIMEOUT, REP_PAUSE_SECONDS,
#   OPENAI_BASE_URL/OPENAI_API_KEY and per-role provider overrides.

[CmdletBinding()]
param(
    [string]$Models = $env:MODELS,
    [string]$ModelRuns = $env:MODEL_RUNS,
    [string]$Scenarios = $env:SCENARIOS,
    [int]$Reps = $(if ($env:REPS) { [int]$env:REPS } else { 5 }),
    [int]$RepPauseSeconds = $(if ($env:REP_PAUSE_SECONDS) { [int]$env:REP_PAUSE_SECONDS } else { 0 }),
    [int]$StartupTimeout = $(if ($env:STARTUP_TIMEOUT) { [int]$env:STARTUP_TIMEOUT } else { 90 }),
    [int]$MaxParallelModels = $(if ($env:MAX_PARALLEL_MODELS) { [int]$env:MAX_PARALLEL_MODELS } else { 2 }),
    [int]$FirstPortOffset = $(if ($env:FIRST_PORT_OFFSET) { [int]$env:FIRST_PORT_OFFSET } else { 100 }),
    [int]$PortStep = $(if ($env:PORT_STEP) { [int]$env:PORT_STEP } else { 100 }),
    [int]$LogPollSeconds = $(if ($env:LOG_POLL_SECONDS) { [int]$env:LOG_POLL_SECONDS } else { 5 }),
    [switch]$ShowLogs = $(if ($env:SHOW_LOGS -and $env:SHOW_LOGS -ne "0") { $true } else { $false })
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = (Resolve-Path (Join-Path $scriptDir "run_smoke_dlatest.ps1")).Path
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Missing runner: $runner"
}
if ($MaxParallelModels -lt 1) {
    throw "MAX_PARALLEL_MODELS must be at least 1"
}
if ($FirstPortOffset -lt 0) {
    throw "FIRST_PORT_OFFSET must be non-negative"
}
if ($PortStep -lt 10) {
    throw "PORT_STEP must be at least 10"
}
if ($LogPollSeconds -lt 1) {
    throw "LOG_POLL_SECONDS must be at least 1"
}

function Split-ModelList {
    param([string]$Value)

    if (-not $Value) {
        return @()
    }
    return @($Value -split "\s+" | Where-Object { $_ })
}

function Split-ModelRuns {
    param([string]$Value)

    $runs = @()
    if (-not $Value) {
        return $runs
    }

    foreach ($rawRun in $Value -split ";") {
        $run = $rawRun.Trim()
        if (-not $run) {
            continue
        }

        $parts = @($run -split "\|" | ForEach-Object { $_.Trim() })
        if ($parts.Count -ne 3 -or -not $parts[0] -or -not $parts[1] -or -not $parts[2]) {
            throw "Invalid MODEL_RUNS entry '$run'. Expected: attacker|defender|normal"
        }

        $runs += [pscustomobject]@{
            Attacker = $parts[0]
            Defender = $parts[1]
            NormalUser = $parts[2]
        }
    }
    return $runs
}

function New-SweepConfig {
    param(
        [int]$Index,
        [string]$Kind,
        [string]$Model,
        [string]$Attacker,
        [string]$Defender,
        [string]$NormalUser
    )

    return [pscustomobject]@{
        Name = "sweep_{0:000}" -f ($Index + 1)
        Kind = $Kind
        Model = $Model
        Attacker = $Attacker
        Defender = $Defender
        NormalUser = $NormalUser
        PortOffset = $FirstPortOffset + ($Index * $PortStep)
    }
}

function Start-SweepJob {
    param([pscustomobject]$Config)

    Write-Host ""
    Write-Host "Launching $($Config.Name) with PORT_OFFSET=$($Config.PortOffset)"
    if ($Config.Kind -eq "same") {
        Write-Host "  model: $($Config.Model)"
    } else {
        Write-Host "  attacker:    $($Config.Attacker)"
        Write-Host "  defender:    $($Config.Defender)"
        Write-Host "  normal_user: $($Config.NormalUser)"
    }

    return Start-Job -Name $Config.Name -ArgumentList @(
        $runner,
        $Config.Kind,
        $Config.Model,
        $Config.Attacker,
        $Config.Defender,
        $Config.NormalUser,
        $Config.PortOffset,
        $Scenarios,
        $Reps,
        $RepPauseSeconds,
        $StartupTimeout,
        $ShowLogs.IsPresent
    ) -ScriptBlock {
        param(
            [string]$Runner,
            [string]$Kind,
            [string]$Model,
            [string]$Attacker,
            [string]$Defender,
            [string]$NormalUser,
            [int]$PortOffset,
            [string]$Scenarios,
            [int]$Reps,
            [int]$RepPauseSeconds,
            [int]$StartupTimeout,
            [bool]$ShowLogs
        )

        $ErrorActionPreference = "Stop"
        Remove-Item Env:OUTROOT -ErrorAction SilentlyContinue

        $runnerArgs = @(
            "-ExecutionPolicy", "Bypass",
            "-File", $Runner,
            "-Reps", "$Reps",
            "-RepPauseSeconds", "$RepPauseSeconds",
            "-StartupTimeout", "$StartupTimeout",
            "-PortOffset", "$PortOffset"
        )
        if ($Scenarios) {
            $runnerArgs += @("-Scenarios", $Scenarios)
        }
        if ($ShowLogs) {
            $runnerArgs += "-ShowLogs"
        }

        if ($Kind -eq "same") {
            $runnerArgs += @(
                "-Model", $Model,
                "-AttackerModel", $Model,
                "-DefenderModel", $Model,
                "-NormalUserModel", $Model
            )
        } else {
            $runnerArgs += @(
                "-AttackerModel", $Attacker,
                "-DefenderModel", $Defender,
                "-NormalUserModel", $NormalUser
            )
        }

        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & powershell @runnerArgs 2>&1 | ForEach-Object { $_ }
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }

        if ($exitCode -ne 0) {
            throw "run_smoke_dlatest.ps1 failed with exit code $exitCode"
        }
    }
}

function Receive-SweepJobOutput {
    param([array]$Jobs)

    foreach ($job in $Jobs) {
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $jobOutput = @(Receive-Job -Job $job -ErrorAction Continue 2>&1)
        } finally {
            $ErrorActionPreference = $oldErrorActionPreference
        }

        foreach ($line in $jobOutput) {
            Write-Host "[$($job.Name)] $line"
        }
    }
}

function Wait-SweepJob {
    param([array]$Jobs)

    $doneJobs = @()
    while ($doneJobs.Count -eq 0) {
        Receive-SweepJobOutput $Jobs
        $doneJobs = @($Jobs | Where-Object { $_.State -ne "Running" -and $_.State -ne "NotStarted" })
        if ($doneJobs.Count -eq 0) {
            Wait-Job -Job $Jobs -Any -Timeout $LogPollSeconds | Out-Null
        }
    }

    Receive-SweepJobOutput $doneJobs
    foreach ($job in $doneJobs) {
        Write-Host ""
        Write-Host "============================================================"
        Write-Host "Finished $($job.Name) with state $($job.State)"
        Write-Host "============================================================"
        if ($job.State -ne "Completed") {
            $script:HadSweepFailure = $true
        }
        Remove-Job -Job $job
    }

    $doneIds = @($doneJobs | ForEach-Object { $_.Id })
    return @($Jobs | Where-Object { $doneIds -notcontains $_.Id })
}

$sameModelRuns = Split-ModelList $Models
$roleModelRuns = Split-ModelRuns $ModelRuns

if (-not $sameModelRuns -and -not $roleModelRuns) {
    $sameModelRuns = @("openai/gpt-oss-20b")
}

$configs = @()
$index = 0
foreach ($model in $sameModelRuns) {
    $configs += New-SweepConfig $index "same" $model $null $null $null
    $index++
}
foreach ($run in $roleModelRuns) {
    $configs += New-SweepConfig $index "roles" $null $run.Attacker $run.Defender $run.NormalUser
    $index++
}

Write-Host "Prepared $($configs.Count) sweep run(s)"
Write-Host "Max parallel model runs: $MaxParallelModels"
Write-Host "First port offset: $FirstPortOffset"
Write-Host "Port step: $PortStep"

$jobs = @()
$script:HadSweepFailure = $false

foreach ($config in $configs) {
    while ($jobs.Count -ge $MaxParallelModels) {
        $jobs = Wait-SweepJob $jobs
    }
    $jobs += Start-SweepJob $config
}

while ($jobs.Count -gt 0) {
    $jobs = Wait-SweepJob $jobs
}

if ($script:HadSweepFailure) {
    throw "One or more sweep jobs failed"
}

Write-Host ""
Write-Host "All sweep jobs completed"
