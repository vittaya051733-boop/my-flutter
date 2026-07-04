# van1 Merchant — Agent Instructions

## Before ANY Firebase deploy

1. Read `Desktop\van2\scripts\DEPLOY_GOVERNANCE.md`
2. Read `Desktop\van2\scripts\DEPLOY_RISK_MATRIX.md`
3. Run readiness: `..\..\..\van2\scripts\deploy-readiness.ps1 -App van1 -Target <target>`
4. Deploy ONE target: `..\..\..\van2\scripts\deploy-self.ps1 -App van1 -Target <target> ...`

## Before removing production code

See `DEPLOY_GOVERNANCE.md` § **Checkpoint ก่อนลบโค้ด**: report impact and wait for user confirmation before delete + deploy.

## Never

- `firebase deploy` without isolated scripts
- Combined firestore+storage+hosting deploy
- Deploy Firestore default from van1 (use van2)

## Allowed targets

`storage`, `hosting`, `functions` (one name at a time)
