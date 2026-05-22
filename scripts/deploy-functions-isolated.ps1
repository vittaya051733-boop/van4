$ErrorActionPreference = 'Stop'

Write-Error 'BLOCKED: van4 has no isolated Cloud Functions codebase in firebase.json. Do not deploy functions from van4; use the owning app/codebase script for the specific function instead.'
exit 1