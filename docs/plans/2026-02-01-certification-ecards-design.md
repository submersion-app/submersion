# Certification eCards (Digital Wallet) Design

**Date:** 2026-02-01
**Status:** Approved

## Overview

Implement a digital certification wallet that displays dive certifications as beautiful, agency-branded cards with export/share capabilities.

## Features

### 1. Dashboard Wallet Widget

**Location:** Dashboard page, new widget card

**Appearance:**
- Compact card showing a mini-stack of top 2-3 certification cards (fanned slightly)
- Highest-level cert shown prominently, others peeking behind
- Badge showing total cert count (e.g., "5 Certifications")
- Tap anywhere to open full wallet view

**Behavior:**
- Displays certs for the active diver profile
- Shows expiry warning indicator if any cert is expiring within 90 days
- Empty state: "Add your first certification" with + button

### 2. Full Wallet View

**Route:** `/certifications/wallet`

**Card Stack Layout:**
- Cards displayed in a vertical stack, each card offset ~30px from the one above
- Active/selected card pulls forward and centers with slight 3D tilt effect
- Swipe up/down or tap to cycle through cards
- Cards cast subtle shadows to enhance depth

**Individual Card Design (Agency-Branded):**
- Credit card aspect ratio (1.586:1, standard CR80)
- Agency-specific background gradient/color:
  - PADI: Blue gradient (#004990 to #0066CC)
  - SSI: Navy to light blue (#1a237e to #42a5f5)
  - NAUI: Green gradient (#1b5e20 to #43a047)
  - GUE: Dark gray (#424242 to #616161)
  - Others: Default teal theme color
- Card content:
  - Top-left: Agency abbreviation in bold
  - Center: Certification name
  - Bottom-left: Diver name, card number
  - Bottom-right: Issue date, expiry status badge
  - Subtle wave/bubble pattern as background texture

**Card Interaction:**
- Tap card: Flip animation to show back (or photo if uploaded)
- Long-press: Context menu (Share, View Details, Edit)
- Swipe left: Quick share action

### 3. Export & Share

**Share Options (Bottom Sheet):**

#### Option A: "Share as Card"
- Renders the styled agency-branded card as a PNG image
- Exactly what you see in the wallet (front or back based on current view)
- Resolution: 1012 x 638 pixels (2x for retina, standard card ratio)
- Uses Flutter's `RepaintBoundary` + `RenderRepaintBoundary.toImage()`

#### Option B: "Share as Certificate"
- Generates a formal certificate-style image
- White background, centered layout
- Content:
  - Agency name at top
  - "This certifies that" text
  - Diver Name (large, bold)
  - "has completed training as"
  - Certification Name (prominent)
  - Issue date, card number
  - QR code placeholder (for future verification)
- Resolution: 1200 x 800 pixels (landscape certificate)

## File Structure

```
lib/features/certifications/
├── presentation/
│   ├── pages/
│   │   └── certification_wallet_page.dart      # Full wallet view
│   ├── widgets/
│   │   ├── certification_wallet_card.dart      # Dashboard widget
│   │   ├── certification_ecard.dart            # Single card widget (reusable)
│   │   ├── certification_ecard_stack.dart      # Stacked cards with gestures
│   │   ├── certification_card_back.dart        # Back of card (photo or generated)
│   │   └── certification_share_sheet.dart      # Share options bottom sheet
│   └── services/
│       └── certification_card_renderer.dart    # Image generation for export
```

## Implementation Phases

### Phase 1: Core Card Component
- Add brand colors to `CertificationAgency` enum
- Build `CertificationEcard` widget with agency-branded design
- Implement flip animation for front/back

### Phase 2: Wallet View
- Create `CertificationEcardStack` with gesture handling
- Build `CertificationWalletPage` with full stack view
- Add route to `app_router.dart`

### Phase 3: Dashboard Widget
- Create `CertificationWalletCard` for dashboard
- Add to dashboard page layout

### Phase 4: Export/Share
- Build `CertificationCardRenderer` service
- Create `CertificationShareSheet` bottom sheet
- Implement both card and certificate export formats

## Technical Notes

### Agency Color Mapping
Add to `CertificationAgency` enum in `enums.dart`:
```dart
Color get primaryColor => switch (this) {
  CertificationAgency.padi => const Color(0xFF004990),
  CertificationAgency.ssi => const Color(0xFF1a237e),
  CertificationAgency.naui => const Color(0xFF1b5e20),
  CertificationAgency.gue => const Color(0xFF424242),
  // ... etc
};

Color get secondaryColor => switch (this) {
  CertificationAgency.padi => const Color(0xFF0066CC),
  CertificationAgency.ssi => const Color(0xFF42a5f5),
  CertificationAgency.naui => const Color(0xFF43a047),
  CertificationAgency.gue => const Color(0xFF616161),
  // ... etc
};
```

### Dependencies
- All packages already available (`share_plus`, existing Flutter rendering APIs)
- No new dependencies needed

### Providers
- Reuses existing `certificationListProvider`
- Add `selectedWalletCardIndexProvider` for tracking active card
