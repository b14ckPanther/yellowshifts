# YellowShifts — Design System & Semantic Tokens

YellowShifts implements a strict semantic design token system derived from the physical station brand identity. No ad-hoc magic numbers or hardcoded colors exist within feature widgets.

---

## 1. Official Palette & Semantic Color Mapping

```
Brand Hex Values:
• #FCBC00 (Brand Surface)
• #FFDB07 (Brand Highlight)
• #D10040 (Text / Accent)
• #F6F6F6 (Neutral App Background)
• #FFFFFF (Raised Surface / Inverse Text)
• #000000 (Primary Text)
```

### Semantic Token Architecture

| Semantic Token | Mapped Value | Purpose & Usage |
| :--- | :--- | :--- |
| `colorSurfaceBase` | `#F6F6F6` | Primary neutral application screen background |
| `colorSurfaceRaised` | `#FFFFFF` | Cards, operational panels, dropdowns, modal sheets |
| `colorSurfaceBrand` | `#FCBC00` | High-impact brand headers, authentication hero panels |
| `colorSurfaceBrandAccent` | `#FFDB07` | Brand highlights, badge backgrounds, active pill highlights |
| `colorSurfaceMuted` | `#EEEEEE` | Table headers, secondary containers, chip backgrounds |
| `colorTextPrimary` | `#000000` | Primary headers, high-emphasis text, body copy |
| `colorTextSecondary` | `#555555` | Secondary descriptions, subheadings, helper labels |
| `colorTextMuted` | `#8E8E93` | Timestamps, metadata, placeholders |
| `colorTextBrand` | `#D10040` | High-emphasis accent text, active tab indicators |
| `colorTextInverse` | `#FFFFFF` | Text rendered on dark or high-contrast brand surfaces |
| `colorBorderSubtle` | `#E5E5EA` | Standard container borders, dividers, list separators |
| `colorBorderStrong` | `#C7C7CC` | Focused input borders, active outlines |
| `colorActionPrimary` | `#D10040` | Primary action buttons (clock in, submit, confirm) |
| `colorActionPrimaryHover` | `#B00036` | Primary action button hover/pressed state |
| `colorStatusSuccess` | `#34C759` | Active shifts, confirmed attendance, completed status |
| `colorStatusWarning` | `#FF9500` | Late arrivals, pending approvals, expiring availability |
| `colorStatusDanger` | `#D10040` | Absences, critical operational alerts, errors |
| `colorStatusInfo` | `#007AFF` | Informational announcements, schedule publications |

---

## 2. Typography System

Typography automatically switches font families based on the active locale to ensure native typographic beauty:
- **English (LTR)**: `GoogleFonts.ubuntu()`
- **Hebrew (RTL)**: `GoogleFonts.heebo()`

### Text Styles Hierarchy

| Text Role | Font Size | Weight | Line Height |
| :--- | :--- | :--- | :--- |
| `displayLarge` | 32px | Bold (700) | 1.2 |
| `titleLarge` | 24px | SemiBold (600) | 1.25 |
| `titleMedium` | 18px | SemiBold (600) | 1.3 |
| `bodyLarge` | 16px | Regular (400) | 1.5 |
| `bodyMedium` | 14px | Regular (400) | 1.4 |
| `labelLarge` | 14px | Medium (500) | 1.2 |
| `caption` | 12px | Regular (400) | 1.3 |
| `numericLarge` | 28px | Bold (700) | 1.1 |
| `numericCompact`| 14px | SemiBold (600) | 1.2 |

---

## 3. Spacing & Radius Scales

- **Spacing**: `space4` (4px), `space8` (8px), `space12` (12px), `space16` (16px), `space20` (20px), `space24` (24px), `space32` (32px), `space48` (48px), `space64` (64px).
- **Radius**: `radiusSm` (6px), `radiusMd` (10px), `radiusLg` (16px), `radiusXl` (24px), `radiusPill` (999px).

---

## 4. Zero-Emoji Policy

YellowShifts enforces a strict 0-emoji rule. All iconography is rendered via the consistent vector library `LucideIcons` / Flutter vector symbols.
