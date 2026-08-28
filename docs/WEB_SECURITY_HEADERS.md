# YellowShifts — Web Security Headers & Content Security Policy (CSP)

## 1. Overview

To protect against Cross-Site Scripting (XSS), Clickjacking, MIME sniffing, and unauthorized framing, the production hosting layer (Cloudflare Pages, Vercel, Netlify, or AWS CloudFront/S3) must serve the following HTTP response headers.

---

## 2. Production Security Headers Configuration

```http
# 1. Enforce HTTPS Strict Transport Security
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload

# 2. Prevent MIME Sniffing
X-Content-Type-Options: nosniff

# 3. Defend Against Clickjacking & Framing
X-Frame-Options: SAMEORIGIN

# 4. Strict Referrer Policy
Referrer-Policy: strict-origin-when-cross-origin

# 5. Restrict Dangerous Device Permissions
Permissions-Policy: camera=(self), microphone=(), geolocation=(), payment=(), usb=()

# 6. Content Security Policy (Optimized for Flutter Web, WASM, Google Fonts, and Supabase)
Content-Security-Policy: default-src 'self'; script-src 'self' 'wasm-unsafe-eval' 'unsafe-inline' https://unpkg.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: blob: https://*.supabase.co; connect-src 'self' https://*.supabase.co wss://*.supabase.co blob: data:; worker-src 'self' blob:; frame-ancestors 'self'; object-src 'none'; base-uri 'self';
```

---

## 3. WebAssembly (WASM) & Flutter Web Considerations

- `'wasm-unsafe-eval'`: Required by modern Chromium and Safari browsers to execute Flutter WASM modules compiled via `dart2wasm`.
- `connect-src https://*.supabase.co wss://*.supabase.co`: Enables HTTPS REST RPCs and WebSockets for Supabase Realtime attendance and schedule updates.
- `camera=(self)`: Permits barcode/QR scanning on employee mobile devices and kiosk cameras.
- `geolocation=()`: Explicitly disabled across all origins to enforce the Zero-GPS Attendance Invariant.
