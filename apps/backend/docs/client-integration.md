# Game client integration

Base URL below is your deployed HTTPS API. All `/v1/games/{gameId}` calls require `Authorization: Bearer <accessToken>`. Game IDs are `ringrush`, another configured game, etc. There is no backend API key embedded in the game and no direct database connection from the client.

## Account lifecycle

| Method / path | Body / result |
| --- | --- |
| POST `/v1/auth/register` | `{email,password}` → generic 202; verify the email |
| POST `/v1/auth/login` | `{email,password}` → accessToken, refreshToken, expiresIn, userId |
| POST `/v1/auth/refresh` | `{refreshToken}` → rotated tokens; call only once at a time |
| GET `/v1/auth/me` | Auth header → userId, emailVerified |
| POST `/v1/auth/resend-verification` | `{email}` → generic 202 |
| POST `/v1/auth/forgot-password` | `{email}` → generic 202 |
| POST `/v1/auth/verify-email` | `{token}` → verified |
| POST `/v1/auth/reset-password` | `{token,password}` → sign in again |
| POST `/v1/auth/logout` | Auth header → revoke this device family |
| POST `/v1/auth/logout-all` | Auth header → revoke every session |

Use Android Keystore / iOS Keychain-backed storage for the refresh token. Do not place it in `CoreSaveStore`, cloud progress or a Git-tracked config. Keep the short-lived access token in memory. Web clients need a reviewed secure token storage strategy (for example a same-origin backend-for-frontend with HttpOnly cookies); the native bearer API does not implement cookies. Offline play may continue with an existing local profile, but paid transactions and cloud upload require a valid login.

## Starting Billing

Call `GET /v1/games/ringrush/billing-context`. It returns:

```json
{"gameId":"ringrush","androidPackage":"YOUR_FINAL_PACKAGE","obfuscatedAccountId":"SERVER_GENERATED_ID","products":[{"id":"coins_500","kind":"consumable","currency":"coins","units":"500","entitlement":null}]}
```

Use the returned `obfuscatedAccountId` in BillingClient **before** launching the purchase flow. Display localized prices from Play Billing product details, not a price hardcoded by the backend. After the SDK callback send:

```http
POST /v1/games/ringrush/purchases/verify
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{"productId":"coins_500","purchaseToken":"TOKEN_RETURNED_BY_GOOGLE"}
```

`PENDING` means wait; no coins or permanent benefit has been granted. `PURCHASED` means the ledger transaction committed. `CANCELLED` is terminal. `finalization: queued` means a worker still needs to acknowledge/consume; the client must **not** acknowledge or consume independently. SDK callbacks can arrive again after restart; repeat verification safely. Refresh on a 401 once, then ask the player to sign in. Do not retry a 4xx account/product mismatch as another user.

## Restore and reconnect

1. Query active purchases with BillingClient and pass up to 20 tokens to `POST /v1/games/{gameId}/purchases/restore` as `{purchaseTokens:[...]}`. Multiple batches are allowed. The service also checks known non-consumables, so an empty Billing response after a refund does not preserve the old entitlement.
2. Fetch `GET /v1/games/{gameId}/save`. A first-time account returns `{save:null}`. An existing cloud save is the base for this account on a new phone.
3. Fetch `/ledger?after=<save.purchaseCursor or 0>`. Apply each `eventId` once, positive purchase and negative refund amounts, then continue through `hasMore` pages. Only advance the local purchase cursor after saving those effects atomically with the game profile. Cursors and amounts are decimal strings.
4. Fetch `/inventory`; replace every IAP key in `managedEntitlements` using the active `entitlements` array. Do not just set returned entitlements to true: that fails to remove refunded rights.
5. Upload game progress with the new revision and the final reconciled purchase cursor. If another ledger change occurred meanwhile, reconcile it and retry. Never advance a save cursor merely because `/inventory` returned a larger number; first apply the missing ledger entries.

The current `CoreCommerce._on_purchase()` locally grants coins from a catalog, and `_on_restore()` only adds flags. Those are mock/native-adapter foundations, not the complete server-sync adapter. Replace that production path with the ledger/cursor reconciliation above to avoid double grants and stale refund entitlements. Preserve local `eventId` receipts for offline crash recovery, but use cloud progress + its cursor when restoring onto another device.

## Cloud progress

```http
PUT /v1/games/ringrush/save
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{
  "expectedRevision":"0",
  "schemaVersion":1,
  "purchaseCursor":"0",
  "payload":{
    "progress":{"selected_character":"atlas","unlocked_stage":2,"equipment_slots":{"air":"medic"}},
    "coins":450,
    "training":{"power":3},
    "settings":{"music":true},
    "iap_debt":0
  }
}
```

The example is a contract illustration, not a replacement for RingRush's exact save schema. Preserve its current validated profile, schema version and resumable run fields. Do not include auth tokens, provider secrets, raw purchase tokens or pending device-local ad promises.

Use revision `0` only for the first upload. The response supplies the next revision. On `409 SAVE_REVISION_CONFLICT`, download the remote save and present a clear choice between device and cloud progress. Do not auto-retry the old payload with the new revision: that silently overwrites newer progress. On `COMMERCE_CHANGED`, apply the new ledger events and update IAP flags before retrying. On `SAVE_SCHEMA_DOWNGRADE`, require a game update.

Sync after settlement/upgrades and on returning to the main menu; debounce ordinary changes and retain local offline saves. Background shutdown is not a reliable final upload opportunity. On account switch, flush or explicitly resolve pending changes, then use a separate local profile for the new user. Never upload the previous user's local progress into a freshly logged-in account automatically.

First import from the 0.8 playtest must exclude mock IAP entitlements/receipts. No real billing transaction exists for those simulated purchases. A player account's first-cloud-import policy should be explicit in the game UX.

## Common errors

- `401 INVALID_ACCESS_TOKEN / SESSION_REVOKED`: refresh once or sign in.
- `403 EMAIL_VERIFICATION_REQUIRED`: complete verification.
- `409 PURCHASE_OWNER_MISMATCH / PURCHASE_GAME_MISMATCH`: never rebind the token; support review.
- `409 CONSUMED_PURCHASE_REQUIRES_MIGRATION`: historical consumed token; no automatic new grant.
- `409 SAVE_REVISION_CONFLICT / COMMERCE_CHANGED`: reconcile before retry.
- `422 PLAY_PURCHASE_UNAVAILABLE`: token invalid, unavailable or outside retention; do not grant locally.
- `429 RATE_LIMITED`: respect Retry-After.
- `503 PLAY_UNAVAILABLE / PLAY_PERMISSION_ERROR`: preserve the token and retry later; service operations may need configuration fixes.
