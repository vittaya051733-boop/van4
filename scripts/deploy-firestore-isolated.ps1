param(
  [string]$ConfirmDeploy,
  [string]$ConfirmFile,
  [string]$ConfirmImpact,
  [switch]$InteractiveConfirm,
  [string]$FinalAcknowledge,
  [switch]$DryRun,
  [string]$DatabaseId = 'van4'
)

$ErrorActionPreference = 'Stop'
$importScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\van2\scripts\deploy-governance-import.ps1'))
. $importScript -CallingScriptRoot $PSScriptRoot

$cfg = Get-VanGovernanceConfig
$appCfg = $cfg.Apps['van4']
$appRoot = $appCfg.Root
$rulesFile = 'firestore.rules'
Set-Location $appRoot

Invoke-VanDeployGuardSession `
  -App 'van4' `
  -ConfirmDeploy $ConfirmDeploy `
  -ConfirmFile $ConfirmFile `
  -ExpectedFile $rulesFile `
  -ConfirmImpact $ConfirmImpact `
  -ExpectedImpact 'SELF:van4' `
  -FinalAcknowledge $FinalAcknowledge `
  -InteractiveConfirm:$InteractiveConfirm

if (-not $appCfg.CanDeployIsolatedFirestore) {
  throw 'van4 isolated Firestore deploy is disabled in governance config.'
}

Write-Host "[guard] van4 deploys ONLY to isolated database '$DatabaseId' (not default/shared)." -ForegroundColor DarkYellow

if (-not (Test-Path $rulesFile)) {
  throw "Missing rules file: $rulesFile"
}

$tempConfig = '.firebase.firestore.van4.tmp.json'
@{
  firestore = @{
    database = $DatabaseId
    rules    = $rulesFile
  }
} | ConvertTo-Json -Depth 5 | Set-Content -Path $tempConfig -Encoding UTF8

try {
  Write-Host "Deploying van4 Firestore rules to database '$DatabaseId' (SELF:van4)" -ForegroundColor Cyan
  if ($DryRun) {
    Write-Host '[dry-run] Skipping firebase deploy for isolated firestore database.' -ForegroundColor Yellow
    return
  }
  firebase deploy --project $cfg.ProjectId --only firestore --config $tempConfig
}
finally {
  if (Test-Path $tempConfig) {
    Remove-Item $tempConfig -Force
  }
}
