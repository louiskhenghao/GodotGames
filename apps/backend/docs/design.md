# Shared backend design

## Ownership and isolation

`users` is a shared ZX Labs account, with a separate `(game_id, user_id)` membership and random 43-character billing identifier per game. The client gets that identifier from `billing-context` and passes it to BillingClient's `setObfuscatedAccountId`. Purchase ownership is determined by the Google response and this server-created mapping, never by a user ID inside the request body. The Android package is read from the server game registry. Purchase tokens have a global unique SHA-256 key; the raw token is AES-256-GCM encrypted for future verification.

Every game route requires a verified email and a live server session. SQL predicates include game and user IDs. PostgreSQL's `backend` schema is private, tables have RLS, and only the dedicated server DB role has policies. Supabase's public client keys cannot access these tables. The runtime role cannot modify the immutable commerce ledger or migration metadata.

## Auth

Passwords use scrypt with a random salt, N=32768, r=8, p=3. Access JWTs last 15 minutes and are issuer/audience/algorithm checked; session revocation is also checked in PostgreSQL. Refresh tokens are random secrets, stored only as hashes, rotate after every use and expire in 30 days. Reusing a rotated token revokes the entire device session family. A new login produces a separate family. Logout-all and password reset revoke all sessions. Serialize refresh on the client: simultaneous refresh requests intentionally trigger reuse protection.

Email verification tokens last 24 hours; reset tokens last 30 minutes. Both are single-use and purpose-bound. Registration and email request responses avoid disclosing whether an account exists. Password reset also verifies possession of the email address and invalidates other outstanding account-action tokens. Email links show a confirmation form on GET; scanners cannot consume them merely by prefetching a link. Tokens appear in the email link, so use HTTPS, keep access logs free of query strings and do not embed third-party analytics on that page.

The encrypted email outbox is processed by the worker. SMTP acceptance means the provider accepted delivery; it is not proof of inbox delivery. Configure SPF/DKIM/DMARC and monitor bounces with the chosen email provider. Database-backed limits apply across API replicas, with separate IP and email limits for login/registration/email requests.

## Purchase transaction

1. Lock the token in PostgreSQL, then query `purchases.productsv2.getproductpurchasev2`. This prevents an earlier Google read from committing after a newer refund read.
2. Check game/package mapping, Google account ID, product, quantity, test environment and ownership. Rentals, preorders, subscriptions and multi-line bundles are not enabled in this version.
3. Lock the game account. Snapshot the product reward in the purchase row. Insert the immutable grant and durable finalization job in the **same transaction**. PENDING never grants anything.
4. The worker consumes a consumable or acknowledges a non-consumable only after the grant commits. If Google succeeds but the worker crashes, the retry reads consumption/acknowledgement state instead of sending a second grant.
5. All paths—client verification, restore, RTDN and reconciliation—use the same transaction function. Duplicate callbacks and repeated restores return the existing grant.

The account lock also orders ledger sequence allocation with transaction commit. Pagination sorts by the numeric sequence, not its JSON string representation. Reward amounts and cursors use decimal strings on the API to preserve bigint precision.

A consumed token never seen by this backend is rejected as requiring migration, because another implementation might already have delivered its coins. Do not silently accept historical consumed tokens during a backend switch. A trusted full-refund event can still create a non-granting cancellation record. For an already verified order whose Google token lookup has expired, an authenticated full-void signal can revoke the existing grant using its persisted ownership; ordinary client requests cannot enable this fallback.

## Refunds and reconciliation

Google Pub/Sub push JWTs must have the configured audience, verified service-account email and Google issuer. The expected subscription and Android package must also match the game registry. A webhook returns 204 only after inserting a durable encrypted inbox job. Duplicate message IDs share a unique key.

Notifications trigger a fresh Google read. Full refunds are terminal; partial quantity refunds append only the newly revoked quantity. Refunds never erase a historical grant. Revoked quantities cannot decrease on an older response. Multiple purchases granting the same non-consumable are considered together, so refunding one order does not revoke another valid purchase.

Every six hours the worker scans the last 29 days of voided purchases, with pagination, including quantity-based partial refunds. Each token becomes its own retryable sync job; one unavailable historical token does not block others. Pending purchases retry periodically, and known permanent products are periodically rechecked. `last_reconciled_at` means the scan was durably enqueued; successful scan status must be considered together with dead/retrying jobs. Outages exceeding the Google list window need operational reconciliation rather than assuming the scan is complete.

Jobs use `FOR UPDATE SKIP LOCKED`, leases, fenced completion, heartbeat extension and exponential retry up to 20 attempts per job. Dead jobs remain inspectable and manually retryable. Monitor overdue finalizations well before Google's acknowledgement deadline. Unsupported subscription or chargeback-review notifications become visible failed jobs rather than being silently discarded.

## Cloud saves and economy boundary

A game has one current JSON save per user, plus nine prior revisions. Uploads carry `expectedRevision`, `schemaVersion` and the last applied `purchaseCursor`. A stale revision returns `SAVE_REVISION_CONFLICT`, and a new grant/refund returns `COMMERCE_CHANGED`. A smaller schema version cannot overwrite a newer save. The backend accepts up to 500,000 bytes of JSON; PostgreSQL applies an additional size constraint.

Game progress is client-authored data, suitable for preserving offline play across devices. This is **not server-authoritative gameplay or anti-cheat**. Clients cannot alter the purchase ledger or real entitlements through a save payload, but the server does not prove that a claimed boss win or earned coin is genuine. Competitive modes or a fully authoritative spend economy need game-specific commands and validation later.

`purchaseCredits.netGranted` is lifetime IAP grants minus refunds, **not a spendable wallet**. Never set the player's current coins to this number on restore. Download the cloud game wallet and apply missing ledger deltas once. If a refund exceeds remaining local coins, track the shortfall as IAP debt and apply future credits against it; silently clamping the refund loses the debt. Always replace managed IAP entitlement flags with the server inventory, including inactive catalog keys in `managedEntitlements`, instead of only adding true flags.

## Keys and retained data

Use separate staging and production databases, service identities, JWT secrets and encryption keys. Keep old encryption keys in `TOKEN_ENCRYPTION_KEYS` during rotation; changing the current key only affects new ciphertext. Back up the keyring separately from encrypted database backups. JWT secret rotation signs everyone out; existing refresh sessions can mint a new access token unless explicitly revoked. Never log auth headers, purchase tokens, passwords, mail URLs or database URLs.

Financial records and audit events are retained; completed auth-email jobs are cleaned after seven days, expired account-action tokens and sessions after an additional seven days. Finalization/notification jobs remain auditable. Define production retention, account deletion/export handling and the matching privacy policy before opening registration to the public. These are not replaced by the old offline-playtest privacy notice.
