param(
  [switch]$BuildWeb,
  [string]$ConfirmDeploy,
  [string]$ConfirmFile,
  [string]$ConfirmImpact,
  [switch]$InteractiveConfirm,
  [string]$FinalAcknowledge,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$importScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\van2\scripts\deploy-governance-import.ps1'))
. $importScript -CallingScriptRoot $PSScriptRoot

$cfg = Get-VanGovernanceConfig
$appCfg = $cfg.Apps['van4']
$storageScript = Join-Path $PSScriptRoot 'deploy-storage-isolated.ps1'

Invoke-VanDeployGuardSession `
  -App 'van4' `
  -ConfirmDeploy $ConfirmDeploy `
  -ConfirmFile $ConfirmFile `
  -ExpectedFile 'firebase.json' `
  -ConfirmImpact $ConfirmImpact `
  -ExpectedImpact 'SELF:van4' `
  -FinalAcknowledge $FinalAcknowledge `
  -InteractiveConfirm:$InteractiveConfirm

Write-Host 'Skipping shared Firestore default DB. van4 admin uses default DB at runtime; optional isolated DB via deploy-firestore-isolated.ps1.' -ForegroundColor DarkYellow
Write-Host 'Deploying isolated Storage (SELF:van4)...' -ForegroundColor DarkCyan
& $storageScript -ConfirmDeploy $ConfirmDeploy -ConfirmFile 'storage.rules' -ConfirmImpact 'SELF:van4' -FinalAcknowledge $FinalAcknowledge -DryRun:$DryRun

Assert-VanAppCanDeploy -App 'van4' -Target 'hosting'
Set-Location $appCfg.Root
$rc = Get-Content (Join-Path $appCfg.Root '.firebaserc') -Raw | ConvertFrom-Json
$hostingTarget = $appCfg.HostingTarget
$hostingMap = $rc.targets.$($cfg.ProjectId).hosting.$hostingTarget
if (-not $hostingMap -or $hostingMap.Count -eq 0) {
  throw "Hosting target '$hostingTarget' is not mapped."
}

if ($BuildWeb) {
  flutter build web
}

Write-Host "Deploying hosting:$hostingTarget (SELF:van4)" -ForegroundColor Cyan
if ($DryRun) {
  Write-Host '[dry-run] Skipping firebase deploy for hosting.' -ForegroundColor Yellow
  return
}
firebase deploy --project $cfg.ProjectId --only "hosting:$hostingTarget"
