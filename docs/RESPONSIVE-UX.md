# YellowShifts — Responsive UX & Adaptive Layouts

This document outlines the multi-device responsive architecture, size classes, and presentation adaptation across Mobile (iOS/Android), Tablet (iPad/Android Kiosks), and Desktop/Web (1080p to 4K displays).

---

## 1. Responsive Size Classes

Layouts are classified into three distinct categories based on viewport width:

```
0px                  600px                 1024px                 1600px+
├──────────────────────┼──────────────────────┼──────────────────────┤
│       COMPACT        │        MEDIUM        │       EXPANDED       │
│    (Phones / iOS /   │   (iPads / Android   │   (Desktop Browsers/ │
│       Android)       │    Tablets / Kiosk)  │   Ultra-wide Screens)│
└──────────────────────┴──────────────────────┴──────────────────────┘
```

- **`Compact` (< 600px)**: Mobile screens optimized for one-handed operation, bottom sheets, safe-area insets, and full-screen drill-downs.
- **`Medium` (600px – 1024px)**: Tablet screens and station wall kiosks optimized for operational floor usage with high-contrast displays, split panels, and collapsible NavigationRail.
- **`Expanded` (> 1024px)**: Desktop / Web views providing dense data grids, persistent navigation sidebars, inspector panes, and keyboard shortcut support.

---

## 2. Phase 4 Attendance Feature Adaptation Matrix

| Feature Screen | Compact (Phone <600px) | Medium (Tablet / Kiosk 600–1024px) | Expanded (Desktop/Web >1024px) |
| :--- | :--- | :--- | :--- |
| **Kiosk Display Screen** | Full-width high-contrast challenge container, 240px QR, manual 6-char fallback | Centered 300px QR with ambient station branding & active clock timer | Maximum 360px QR container, full-screen kiosk ambient mode with status indicator |
| **Employee Attendance Screen** | Hero status card, live timer ticker, floating scan button & recent history | Two-column layout: live status card on left, recent shifts on right | Multi-panel dashboard with shift schedule preview and monthly summary |
| **Manager Live Attendance Screen** | KPI horizontal metric chips + tabbed filterable roster | KPI 4-stat metric grid + 2-column live staff roster cards | KPI header row + full multi-column data table with live time badges & quick correction action |
| **Manager Kiosk Devices Screen** | Vertical card list with health status chips & quick actions | Grid of kiosk cards (2 columns) with QR test modal | Data table with IP/last seen timestamps, credential version, and inline rotation modal |
| **Manual Correction Modal** | Full-height bottom sheet with time pickers & validation hints | Centered modal dialog with interval timeline slider | Side inspector panel with real-time overlap preview |
| **Employee My Hours (`/hours`)** | 2-column KPI grid, active session banner, chronological shift cards | 4-column KPI row, active session banner, chronological shift cards | 4-column KPI row, active session banner, multi-column chronological shift list |
| **Manager Operational Reports (`/reports`)** | 2-column KPI grid, mode switch tabs, mobile employee cards, bottom sheet drilldown | 3-column KPI grid, mode switch tabs, horizontal scroll data table, modal drilldown | 5-column executive KPI row, full sorting data table, side-by-side or modal employee drilldown, full daily shift board |
| **Audit Center (`/audit-center`)** | Filter chips, search bar, card list of sanitized audit events | Filter bar, 2-column event stream with JSON metadata viewer | Filter toolbar, high-density audit data table with search, category facets, and metadata inspector |
| **Station Settings (`/station-settings`)** | Vertical form, timezone picker, safety deactivation modal | 2-column grouped settings (General & Policies) | Multi-card layout with live telemetry banner, timezone selector, and force deactivation safety dialog |
| **Export Request & History Modal** | Full-width bottom sheet with format picker (PDF/CSV) and download link | Centered modal with date range picker, format selector, and recent exports list | Side drawer or centered dialog with real-time export progress, signed URL download buttons, and status badges |
| **Employee Management (`/employees`)** | Search bar, employee card list with role chips and edit bottom sheet | 2-column employee grid with quick-edit modals | Full data table with search, role dropdowns, E.164 phone editor, email display, and last-admin warning banners |

---

## 3. Typography & Directionality (RTL/LTR)

- **Hebrew Support**: All labels, cards, and data flows support right-to-left layout directionality using the `Heebo` typeface.
- **English & Numeric Support**: Monospace codes (e.g. `YLW-KRD-01`, `YQ_...`, `TAB-KRD-01`) and time intervals (e.g. `08:00 – 16:00`) maintain LTR directionality using the `Ubuntu` font family.
- **Zero Emoji Compliance**: All status indicators utilize strictly SVG vector icons from `lucide_icons_flutter`.


