# YellowShifts — Station Kiosk Architecture & Operations

## 1. Overview
Station Kiosks are dedicated physical hardware devices (e.g. Android tablets, iPads, or wall-mounted touch displays) deployed at gas station cash registers, staff break rooms, or manager offices.

Kiosks run in dedicated full-screen mode (`/kiosk`), broadcasting rotating cryptographic QR challenges that authenticate physical worker presence without relying on flaky or intrusive GPS permissions.

---

## 2. Security Model & Secrets

### 2.1 One-Way Secret Hashing
- When a station administrator provisions a new kiosk (`provision_kiosk_device`), the database generates a 32-byte cryptographically secure random secret (`raw_secret`).
- The plaintext secret is returned **EXACTLY ONCE** to the admin for initial device configuration.
- The database stores ONLY the SHA-256 hash:
  $$\text{secret\_hash} = \text{encode}(\text{digest}(\text{raw\_secret}, \text{'sha256'}), \text{'hex'})$$
- Plaintext secrets are never stored in any database column, audit log, or error response.

### 2.2 Device Authentication & Session
- To request/refresh a dynamic QR challenge, the kiosk calls:
  `public.kiosk_authenticate_and_mint_qr(p_station_id, p_device_identifier, p_device_secret)`
- Verifies `is_active = true` (fails `P0018` if deactivated).
- Verifies SHA-256 hash match against stored `secret_hash` (fails `P0019` if credentials invalid).
- Automatically updates `last_seen_at = now()`.

### 2.3 Credential Rotation & Deactivation
- **Rotation (`rotate_kiosk_credentials`)**:
  - Replaces `secret_hash` with a newly minted secret hash.
  - Increments `credential_version`.
  - Immediately revokes all active QR challenges for that device.
  - Old tablet sessions immediately fail on next 30s cycle with `P0019`.
- **Deactivation (`deactivate_kiosk_device`)**:
  - Sets `is_active = false`.
  - Immediately revokes active challenges.
- **Reactivation (`reactivate_kiosk_device`)**:
  - Restores `is_active = true`.

### 2.4 Kiosk Health & Heartbeats
- A kiosk is deemed **Online** if `last_seen_at` is within the last 3 minutes.
- When inactive or idle for $>3$ minutes, status switches to **Offline / Idle** with a visual status pill in the Admin device console (`/settings/kiosks`).

---

## 3. Dedicated Kiosk Route (`/kiosk`)
- Tablet-optimized full-screen landscape layout.
- Station branding, Hebrew/English bilingual support.
- Live clock with second-level accuracy.
- High-contrast QR code with smooth 30s circular countdown progress ring.
- Fallback 6-character short code display (`displayCode`).
- Automated 30s background challenge refresh.
- Administrator setup / connect dialog with credential persistence in device memory.
