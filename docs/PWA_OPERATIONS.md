# YellowShifts — Progressive Web Application (PWA) Operational Guide

## 1. Overview & Architecture

YellowShifts is engineered as a zero-install, multiplatform Progressive Web Application (PWA) running on iOS, iPadOS, Android, macOS, Windows, and Linux.

### Key Capabilities
- **Installability**: Standalone display mode with custom splash, yellow/black branding, and app shortcuts.
- **RTL & Hebrew Support**: Full bidirectionality metadata (`"dir": "auto"`, `"lang": "he"`).
- **Responsive Layout Matrix**: Dynamic layout adaptation across compact (mobile), medium (tablet/foldable), and expanded (desktop/widescreen) display profiles.
- **Offline Resiliency**: In-flight state caching, non-intrusive connectivity indicators, and grace-period reconciliation.

---

## 2. PWA Manifest Specifications

`web/manifest.json`:
```json
{
    "name": "YellowShifts",
    "short_name": "YellowShifts",
    "description": "YellowShifts — Modern Workforce Operations & Scheduling Platform",
    "start_url": "/",
    "display": "standalone",
    "background_color": "#121417",
    "theme_color": "#F59E0B",
    "dir": "auto",
    "lang": "he",
    "categories": ["business", "productivity", "utilities"],
    "orientation": "any",
    "prefer_related_applications": false
}
```

---

## 3. Caching & Lifecycle Strategy

### 3.1 Network Awareness & Recovery
- **Offline Mode**: `AppConnectivityBanner` displays a slim red notification bar with `LucideIcons.wifiOff`. Unsafe write mutations are blocked with an immediate warning toast.
- **Reconnecting State**: `AppConnectivityBanner` transitions to brand yellow with a rotating sync icon when the network is restored.
- **Dynamic QR Defense**: When a station kiosk tablet experiences a network disconnection, `DynamicQrDisplay` blurs the QR canvas, disables the 30-second broadcast timer, and displays an explicit offline alert to prevent employees from scanning invalid challenges.

### 3.2 Update Lifecycle
- When a new deployment version is detected, `AppUpdateBanner` displays a non-blocking prompt allowing users to refresh the application at their convenience without interrupting active workflows.

---

## 4. Browser Support & Performance Benchmarks

| Platform / Browser | Engine | CanvasKit | WebAssembly (WASM) | PWA Install |
| :--- | :--- | :---: | :---: | :---: |
| Chrome / Edge 119+ | Chromium / Blink | Supported | Supported | Full Native |
| Safari 16.4+ (iOS / macOS) | WebKit | Supported | Supported | Add to Home Screen |
| Firefox 120+ | Gecko | Supported | Supported | Supported |
| Samsung Internet 22+ | Chromium | Supported | Supported | Full Native |

---

## 5. Security & Isolation within Browser

- **Authentication Storage**: Supabase session tokens stored in secure browser local storage with strict origin isolation.
- **Zero Raw Secrets**: The web client bundle contains only the public `SUPABASE_ANON_KEY`. All privileged actions (user creation, password reset, session revocation) route through serverless Edge Functions.
- **No Third-Party Analytics Tracking**: Zero third-party trackers or ad SDKs included in the runtime bundle.
