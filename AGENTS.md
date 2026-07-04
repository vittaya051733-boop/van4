# van4 Admin — Agent Instructions

## Before ANY Firebase deploy

1. Read `..\van2\scripts\DEPLOY_GOVERNANCE.md`
2. Read `..\van2\scripts\DEPLOY_RISK_MATRIX.md`
3. Run `..\van2\scripts\deploy-readiness.ps1 -App van4 -Target <target>`
4. Deploy ONE target: `..\van2\scripts\deploy-self.ps1 -App van4 -Target <target> ...`

## Before removing production code

See `DEPLOY_GOVERNANCE.md` § **Checkpoint ก่อนลบโค้ด**: report impact and wait for user confirmation before delete + deploy.

## Allowed targets

`storage`, `hosting`, `firestore-van4` (isolated DB)

## Never

- Firestore default DB deploy (SHARED)
- Cloud Functions
- Raw `firebase deploy`
