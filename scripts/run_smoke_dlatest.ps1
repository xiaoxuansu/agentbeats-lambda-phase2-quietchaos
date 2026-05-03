# Smoke test: A_qc (v23 attacker) vs Defender_latest (strongest submitted defender).
#
# Native PowerShell version of scripts/run_smoke_dlatest.sh for Windows users.
#
# Env overrides:
#   MODEL              Shared fallback for attacker, defender, and normal_user.
#                      Default: openai/gpt-oss-20b
#   ATTACKER_MODEL     Attacker model override. Defaults to MODEL.
#   DEFENDER_MODEL     Defender model override. Defaults to MODEL.
#   NORMAL_USER_MODEL  Normal-user model override. Defaults to MODEL.
#   ATTACKER_OPENAI_BASE_URL / ATTACKER_OPENAI_API_KEY
#                      Attacker provider override. Defaults to OPENAI_BASE_URL/API_KEY.
#   DEFENDER_OPENAI_BASE_URL / DEFENDER_OPENAI_API_KEY
#                      Defender provider override. Defaults to OPENAI_BASE_URL/API_KEY.
#   NORMAL_USER_OPENAI_BASE_URL / NORMAL_USER_OPENAI_API_KEY
#                      Normal-user provider override. Defaults to OPENAI_BASE_URL/API_KEY.
#   SCENARIOS          Space-separated scenario list.
#   REPS               Number of reps per scenario.
#   OUTROOT            Output directory. Set this per model when running a sweep.
#   TMPROOT            Temporary TOML output directory.

[CmdletBinding()]
param(
    [string]$Model = $env:MODEL,
    [string]$AttackerModel = $env:ATTACKER_MODEL,
    [string]$DefenderModel = $env:DEFENDER_MODEL,
    [string]$NormalUserModel = $env:NORMAL_USER_MODEL,
    [string]$AttackerOpenAIBaseUrl = $env:ATTACKER_OPENAI_BASE_URL,
    [string]$AttackerOpenAIApiKey = $env:ATTACKER_OPENAI_API_KEY,
    [string]$DefenderOpenAIBaseUrl = $env:DEFENDER_OPENAI_BASE_URL,
    [string]$DefenderOpenAIApiKey = $env:DEFENDER_OPENAI_API_KEY,
    [string]$NormalUserOpenAIBaseUrl = $env:NORMAL_USER_OPENAI_BASE_URL,
    [string]$NormalUserOpenAIApiKey = $env:NORMAL_USER_OPENAI_API_KEY,
    [string]$Scenarios = $env:SCENARIOS,
    [int]$Reps = $(if ($env:REPS) { [int]$env:REPS } else { 2 }),
    [string]$OutRoot = $env:OUTROOT,
    [string]$TmpRoot = $env:TMPROOT,
    [int]$StartupTimeout = $(if ($env:STARTUP_TIMEOUT) { [int]$env:STARTUP_TIMEOUT } else { 90 }),
    [switch]$ShowLogs = $(if ($env:SHOW_LOGS -and $env:SHOW_LOGS -ne "0") { $true } else { $false })
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

function Load-DotEnv {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "ERROR: .env not found. Copy .env.example and set OPENAI_BASE_URL/OPENAI_API_KEY."
    }

    foreach ($rawLine in Get-Content -LiteralPath $Path) {
        $line = $rawLine.Trim()
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }

        $idx = $line.IndexOf("=")
        if ($idx -lt 1) {
            continue
        }

        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        [Environment]::SetEnvironmentVariable($key, $value, "Process")
    }
}

function Set-AgentModel {
    param(
        [string]$Content,
        [string]$Module,
        [string]$AgentModel
    )

    $escapedModule = [regex]::Escape($Module)
    $pattern = "(cmd\s*=\s*`"[^`"]*$escapedModule[^`"]*--model\s+)[^`"\s]+"
    return [regex]::Replace($Content, $pattern, {
        param($match)
        $match.Groups[1].Value + $AgentModel
    })
}

function Set-AgentEnv {
    param(
        [string]$Content,
        [string]$Module,
        [string]$RolePrefix,
        [string]$BaseUrl,
        [string]$ApiKey
    )

    $entries = @()
    if ($BaseUrl) {
        $entries += 'OPENAI_BASE_URL = "${' + $RolePrefix + '_OPENAI_BASE_URL}"'
    }
    if ($ApiKey) {
        $entries += 'OPENAI_API_KEY = "${' + $RolePrefix + '_OPENAI_API_KEY}"'
    }
    if (-not $entries) {
        return $Content
    }

    $escapedModule = [regex]::Escape($Module)
    $pattern = "(cmd\s*=\s*`"[^`"]*$escapedModule[^`"]*`")"
    $envLine = "env = { " + ($entries -join ", ") + " }"
    return [regex]::Replace($Content, $pattern, {
        param($match)
        $match.Groups[1].Value + "`n" + $envLine
    })
}

Load-DotEnv ".env"

if (-not $env:OPENAI_BASE_URL) {
    throw "ERROR: OPENAI_BASE_URL not set in .env"
}

$baseUrl = $env:OPENAI_BASE_URL.TrimEnd("/")
$headers = @{}
if ($env:OPENAI_API_KEY) {
    $headers["Authorization"] = "Bearer $($env:OPENAI_API_KEY)"
}

$uvCommand = "uv"
if (-not (Get-Command $uvCommand -ErrorAction SilentlyContinue)) {
    $localUv = Join-Path $HOME ".local\bin\uv.exe"
    if (Test-Path -LiteralPath $localUv) {
        $uvCommand = $localUv
    } else {
        throw "ERROR: uv not found. Install uv, then reopen PowerShell or add $HOME\.local\bin to PATH."
    }
}

Write-Host "Verifying OpenAI-compatible endpoint at $baseUrl..."
try {
    Invoke-WebRequest -Uri "$baseUrl/models" -Headers $headers -TimeoutSec 5 -UseBasicParsing | Out-Null
} catch {
    throw "ERROR: Cannot reach $baseUrl/models. Check OPENAI_BASE_URL and OPENAI_API_KEY in .env. $($_.Exception.Message)"
}
Write-Host "OpenAI-compatible endpoint reachable"

if (-not $Model -and $env:MODEL) {
    $Model = $env:MODEL
}
if (-not $Model) {
    $Model = "openai/gpt-oss-20b"
}
if (-not $AttackerModel -and $env:ATTACKER_MODEL) {
    $AttackerModel = $env:ATTACKER_MODEL
}
if (-not $AttackerModel) {
    $AttackerModel = $Model
}
if (-not $DefenderModel -and $env:DEFENDER_MODEL) {
    $DefenderModel = $env:DEFENDER_MODEL
}
if (-not $DefenderModel) {
    $DefenderModel = $Model
}
if (-not $NormalUserModel -and $env:NORMAL_USER_MODEL) {
    $NormalUserModel = $env:NORMAL_USER_MODEL
}
if (-not $NormalUserModel) {
    $NormalUserModel = $Model
}
if (-not $AttackerOpenAIBaseUrl) {
    $AttackerOpenAIBaseUrl = $env:ATTACKER_OPENAI_BASE_URL
}
if (-not $AttackerOpenAIApiKey) {
    $AttackerOpenAIApiKey = $env:ATTACKER_OPENAI_API_KEY
}
if (-not $DefenderOpenAIBaseUrl) {
    $DefenderOpenAIBaseUrl = $env:DEFENDER_OPENAI_BASE_URL
}
if (-not $DefenderOpenAIApiKey) {
    $DefenderOpenAIApiKey = $env:DEFENDER_OPENAI_API_KEY
}
if (-not $NormalUserOpenAIBaseUrl) {
    $NormalUserOpenAIBaseUrl = $env:NORMAL_USER_OPENAI_BASE_URL
}
if (-not $NormalUserOpenAIApiKey) {
    $NormalUserOpenAIApiKey = $env:NORMAL_USER_OPENAI_API_KEY
}
if (-not $OutRoot) {
    $OutRoot = "results/cross_smoke/A_qc_vs_D_latest"
}
if (-not $TmpRoot) {
    $TmpRoot = "results/tmp/dlatest_tomls"
}

if ($Scenarios) {
    $scenarioList = @($Scenarios -split "\s+" | Where-Object { $_ })
} else {
    $scenarioList = @(
        "portfolioiq",
        "thingularity",
        "gymjailbreak",
        "resume_downgrade",
        "medical_records"
    )
}

New-Item -ItemType Directory -Force -Path $OutRoot, $TmpRoot | Out-Null

$startTime = Get-Date
$total = $scenarioList.Count * $Reps
$count = 0

foreach ($scenario in $scenarioList) {
    $baseToml = "scenarios/security_arena/scenario_${scenario}_acq_vs_dx.toml"
    $toml = Join-Path $TmpRoot "scenario_${scenario}_acq_vs_dlatest.toml"

    if (-not (Test-Path -LiteralPath $baseToml)) {
        throw "ERROR: missing base TOML: $baseToml"
    }

    $content = Get-Content -LiteralPath $baseToml -Raw
    $content = $content -replace "attacker_quietchaos_v23 vs Defender_x.*", "attacker_quietchaos_v23 vs Defender_latest (strongest submitted defender)"
    $content = $content -replace "scenarios\.security_arena\.agents\.quietchaos_v4_defender\.agent", "scenarios.security_arena.agents.defender.agent"
    $content = Set-AgentModel $content "scenarios.security_arena.agents.attacker.agent" $AttackerModel
    $content = Set-AgentModel $content "scenarios.security_arena.agents.defender.agent" $DefenderModel
    $content = Set-AgentModel $content "scenarios.security_arena.agents.normal_user.agent" $NormalUserModel
    $content = Set-AgentEnv $content "scenarios.security_arena.agents.attacker.agent" "ATTACKER" $AttackerOpenAIBaseUrl $AttackerOpenAIApiKey
    $content = Set-AgentEnv $content "scenarios.security_arena.agents.defender.agent" "DEFENDER" $DefenderOpenAIBaseUrl $DefenderOpenAIApiKey
    $content = Set-AgentEnv $content "scenarios.security_arena.agents.normal_user.agent" "NORMAL_USER" $NormalUserOpenAIBaseUrl $NormalUserOpenAIApiKey

    $tomlFullPath = [System.IO.Path]::GetFullPath($toml)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tomlFullPath, $content, $utf8NoBom)

    for ($rep = 1; $rep -le $Reps; $rep++) {
        $count++
        $outDir = Join-Path $OutRoot "${scenario}_rep${rep}"
        $resultPath = Join-Path $outDir "result.json"

        Write-Host ""
        Write-Host "============================================================"
        Write-Host "[$count/$total] $scenario rep $rep"
        Write-Host "         output: $outDir"
        Write-Host "============================================================"

        if (Test-Path -LiteralPath $resultPath) {
            Write-Host "result.json already exists, skipping (delete to rerun)"
            continue
        }

        New-Item -ItemType Directory -Force -Path $outDir | Out-Null

        $oldResultsDir = $env:AGENTBEATS_RESULTS_DIR
        $env:AGENTBEATS_RESULTS_DIR = $outDir
        try {
            $oldErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $agentbeatsArgs = @("run", "agentbeats-run", $toml, "--startup-timeout", "$StartupTimeout")
            if ($ShowLogs) {
                $agentbeatsArgs += "--show-logs"
            }
            $output = & $uvCommand @agentbeatsArgs 2>&1
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = $oldErrorActionPreference
            $output | Select-Object -Last 40
            if ($exitCode -ne 0) {
                Write-Warning "battle failed, continuing with next"
            }
        } finally {
            if ($null -ne $oldErrorActionPreference) {
                $ErrorActionPreference = $oldErrorActionPreference
            }
            if ($null -eq $oldResultsDir) {
                Remove-Item Env:AGENTBEATS_RESULTS_DIR -ErrorAction SilentlyContinue
            } else {
                $env:AGENTBEATS_RESULTS_DIR = $oldResultsDir
            }
        }
    }
}

$elapsed = [int]((Get-Date) - $startTime).TotalSeconds
$aggregateRoot = Split-Path -Parent $OutRoot

Write-Host ""
Write-Host "============================================================"
Write-Host "DONE. Elapsed: ${elapsed}s"
Write-Host "Refresh tables with:"
Write-Host "  python -X utf8 scripts/tag_patterns.py `"$aggregateRoot`""
Write-Host "  python -X utf8 scripts/aggregate_benchmark.py `"$aggregateRoot`""
Write-Host "============================================================"
