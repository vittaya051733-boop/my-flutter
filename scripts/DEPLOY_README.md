# Deploy (van1 Merchant)

**อ่านก่อน deploy ทุกครั้ง:**
- `Desktop\van2\scripts\DEPLOY_GOVERNANCE.md`
- `Desktop\van2\scripts\DEPLOY_RISK_MATRIX.md`

```powershell
# Readiness + deploy แยกทีละ target
..\..\..\van2\scripts\deploy-readiness.ps1 -App van1 -Target storage
..\..\..\van2\scripts\deploy-self.ps1 -App van1 -Target storage `
  -ConfirmDeploy "APPROVE:van1:van-merchant" -FinalAcknowledge "YES I UNDERSTAND"
```

Manifest: `Desktop\van2\scripts\deploy-governance.ps1`
