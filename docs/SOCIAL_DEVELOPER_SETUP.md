# Social Dashboard — Developer App Setup (Phase 0)

คู่มือสมัคร OAuth apps สำหรับ van4 Social Dashboard (FB/IG + YouTube + TikTok)

## 1. GCP Secret Manager (van-merchant project)

รันจาก repo van2:

```powershell
cd C:\Users\TAM\Desktop\van2\scripts
.\setup-social-secrets.ps1 -Interactive
```

Secrets ที่ต้องมี (Firebase Functions `defineSecret`):

| Secret | ใช้กับ |
|--------|--------|
| `SOCIAL_META_APP_ID` | Meta Graph OAuth |
| `SOCIAL_META_APP_SECRET` | Meta Graph OAuth |
| `SOCIAL_GOOGLE_OAUTH_CLIENT_ID` | YouTube upload |
| `SOCIAL_GOOGLE_OAUTH_CLIENT_SECRET` | YouTube upload |
| `SOCIAL_TIKTOK_CLIENT_KEY` | TikTok Content Posting |
| `SOCIAL_TIKTOK_CLIENT_SECRET` | TikTok Content Posting |
| `SOCIAL_OAUTH_STATE_SECRET` | HMAC สำหรับ OAuth state (สุ่ม 32+ bytes) |
| `SOCIAL_META_WEBHOOK_VERIFY_TOKEN` | Meta webhook verification |

Grant access ให้ Cloud Functions service account อ่าน secrets ใน GCP Console → Secret Manager → Permissions

## 2. Meta (Facebook + Instagram)

1. สร้าง App ที่ [developers.facebook.com](https://developers.facebook.com) → ประเภท Business
2. เพิ่ม products: **Facebook Login**, **Webhooks**, **Instagram Graph API**
3. OAuth redirect URI (production):
   - `https://asia-southeast1-van-merchant.cloudfunctions.net/socialOAuthCallback`
4. Permissions (App Review):
   - `pages_manage_posts`, `pages_read_engagement`, `pages_show_list`
   - `instagram_basic`, `instagram_content_publish`
5. เชื่อม Facebook Page กับ Instagram Business account
6. Webhooks → Page → `feed`, `comments` → callback URL:
   - `https://asia-southeast1-van-merchant.cloudfunctions.net/metaSocialWebhook`

## 3. Google / YouTube

1. GCP Console → APIs & Services → Enable **YouTube Data API v3**
2. OAuth consent screen (Internal หรือ External)
3. OAuth client (Web application) → Authorized redirect URI เดียวกับ Meta callback
4. Scopes: `youtube.upload`, `youtube.force-ssl`, `youtube.readonly`

## 4. TikTok

1. [developers.tiktok.com](https://developers.tiktok.com) → Create app
2. ขอ **Content Posting API** + **Comment API**
3. Redirect URI เดียวกับ callback function
4. Scopes: `video.publish`, `video.upload`, `comment.list`, `comment.list.manage`

## 5. Deploy functions (ทีละชื่อ)

หลัง secrets พร้อม:

```powershell
cd C:\Users\TAM\Desktop\van2
scripts\deploy-self.ps1 -App van2 -Target functions -FunctionName getSocialOAuthUrl -ConfirmDeploy "APPROVE:van2:van-merchant" -FinalAcknowledge "YES I UNDERSTAND"
# ... ทีละ function ตาม deploy-governance
```

Functions ที่เกี่ยวข้อง: `getSocialOAuthUrl`, `socialOAuthCallback`, `listSocialAccounts`, `disconnectSocialAccount`, `createSocialPost`, `publishSocialPostWorker`, `metaSocialWebhook`, `syncSocialComments`, `replySocialComment`, `retrySocialPostPlatform`

## 6. van4 Firestore + Storage

```powershell
cd C:\Users\TAM\Desktop\van4
..\van2\scripts\deploy-self.ps1 -App van4 -Target firestore-van4 -ConfirmDeploy "APPROVE:van4:van-merchant" -FinalAcknowledge "YES I UNDERSTAND"
..\van2\scripts\deploy-self.ps1 -App van4 -Target storage -ConfirmDeploy "APPROVE:van4:van-merchant" -FinalAcknowledge "YES I UNDERSTAND"
```
