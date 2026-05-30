# Deploy (van4 Admin)

**อ่านก่อน deploy ทุกครั้ง:**
- `..\van2\scripts\DEPLOY_GOVERNANCE.md`
- `..\van2\scripts\DEPLOY_RISK_MATRIX.md`

```powershell
..\van2\scripts\deploy-self.ps1 -App van4 -Target storage `
  -ConfirmDeploy "APPROVE:van4:van-merchant" -FinalAcknowledge "YES I UNDERSTAND"
```

Manifest: `..\van2\scripts\deploy-governance.ps1`
