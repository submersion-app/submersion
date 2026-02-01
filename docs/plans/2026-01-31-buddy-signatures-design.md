# Buddy Digital Signatures Design

**Date:** 2026-01-31
**Status:** Approved
**Scope:** Buddy sign-off on dives + PDF export integration

## Overview

Add the ability for dive buddies to digitally sign dive log entries, with signatures displayed in PDF exports. This extends the existing instructor signature system to support buddy verification.

## Requirements

1. **Buddy signatures** - Any buddy associated with a dive can sign it on-device
2. **PDF display** - Signatures appear inline with dive entries in exported PDFs

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Extend existing signature system | Reuse proven capture/storage code |
| Signing method | On-device (hand phone to buddy) | Works offline, no backend needed |
| UI location | Signatures section on Dive Detail page | Natural place, sign after logging |
| Who can sign | Any buddy on the dive | Flexible; role is captured for context |
| PDF layout | Inline with dive entries | Keeps signature in context with dive |

## Database Changes

### Media Table Addition

```dart
// Add to Media table in database.dart
TextColumn get signatureType => text().nullable()(); // 'instructor' | 'buddy'
```

Existing signatures default to `null` (treated as instructor for backward compatibility).

### Migration

Schema version bump with column addition. No data migration needed.

## Entity Changes

### Signature Entity

```dart
// lib/features/signatures/domain/entities/signature.dart

enum SignatureType { instructor, buddy }

class Signature {
  final int id;
  final int diveId;
  final String filePath;
  final int? signerId;        // Links to Buddy record
  final String signerName;
  final DateTime signedAt;
  final SignatureType? type;  // NEW: distinguish instructor vs buddy
  final String? role;         // NEW: buddy's role on this dive (buddy, instructor, divemaster, etc.)

  bool get isBuddySignature => type == SignatureType.buddy;
  bool get isInstructorSignature => type == SignatureType.instructor || type == null;

  // copyWith, equality, etc.
}
```

## Service Changes

### SignatureStorageService

Add methods to `lib/features/signatures/data/services/signature_storage_service.dart`:

```dart
/// Get all buddy signatures for a dive
Future<List<Signature>> getBuddySignaturesForDive(int diveId);

/// Get buddies who haven't signed this dive
Future<List<BuddyWithRole>> getUnsignedBuddiesForDive(int diveId);

/// Save a buddy signature
Future<Signature> saveBuddySignature({
  required int diveId,
  required int buddyId,
  required String buddyName,
  required String role,
  required Uint8List signatureBytes,
});

/// Check if a specific buddy has signed
Future<bool> hasBuddySigned(int diveId, int buddyId);
```

## UI Components

### Dive Detail Page Section

New section appearing after Buddies section:

```
Signatures
├── Signed buddy cards (with signature preview)
└── Unsigned buddy cards (with "Request Signature" button)
```

### New Widgets

| Widget | File | Purpose |
|--------|------|---------|
| `BuddySignaturesSection` | `buddy_signatures_section.dart` | Container widget for dive detail |
| `BuddySignatureCard` | `buddy_signature_card.dart` | Shows signed/unsigned state |
| `BuddySignatureRequestSheet` | `buddy_signature_request_sheet.dart` | Full-screen capture with handoff message |

### Signature Request Flow

1. User taps "Request Signature" on unsigned buddy card
2. Bottom sheet opens: "Hand your device to **[Buddy Name]** to sign"
3. Buddy sees signature canvas (reuses `SignatureCaptureWidget`)
4. Buddy signs and taps "Done"
5. Sheet closes, card updates to show signed state

### Reused Widgets

- `SignatureCaptureWidget` - Touch canvas for drawing signature
- `SignatureDisplayWidget` - Preview of captured signature

## PDF Export Changes

### Layout

Signatures appear at the bottom of each dive entry:

```
┌─────────────────────────────────────────────────────────┐
│ Dive #42 - Blue Corner, Palau                           │
│ Jan 15, 2024 at 10:30 AM                                │
├─────────────────────────────────────────────────────────┤
│ Depth: 32m  Duration: 52min  Temp: 28C  Air: 210-50 bar│
├─────────────────────────────────────────────────────────┤
│ Notes: Amazing drift dive with mantas...                │
├─────────────────────────────────────────────────────────┤
│ Verified by:                                            │
│ ┌──────────────┐  ┌──────────────┐                      │
│ │ [signature]  │  │ [signature]  │                      │
│ │ John Smith   │  │ Sarah Jones  │                      │
│ │ Instructor   │  │ Buddy        │                      │
│ │ Jan 15, 2024 │  │ Jan 15, 2024 │                      │
│ └──────────────┘  └──────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

### Implementation

Updates to `lib/core/services/export_service.dart`:

1. **Load signatures** - Fetch all signatures (instructor + buddy) for each dive
2. **Embed images** - Convert PNG file paths to `pw.MemoryImage`
3. **Build signature row** - Horizontal layout, 3 per row max, wrap if more
4. **Conditional display** - Only show "Verified by:" section if signatures exist

### Signature Block Sizing

- Image: 80pt x 40pt
- Name: 8pt bold
- Role + date: 7pt gray
- Spacing: 8pt between blocks

## File Changes Summary

### Modified Files

| File | Changes |
|------|---------|
| `lib/core/database/database.dart` | Add `signatureType` column, bump schema version |
| `lib/features/signatures/domain/entities/signature.dart` | Add `type`, `role` fields and enum |
| `lib/features/signatures/data/services/signature_storage_service.dart` | Add buddy signature methods |
| `lib/features/signatures/presentation/providers/signature_providers.dart` | Add buddy signature providers |
| `lib/features/dives/presentation/pages/dive_detail_page.dart` | Add signatures section |
| `lib/core/services/export_service.dart` | Embed signatures in PDF |

### New Files

| File | Purpose |
|------|---------|
| `lib/features/signatures/presentation/widgets/buddy_signatures_section.dart` | Section widget |
| `lib/features/signatures/presentation/widgets/buddy_signature_card.dart` | Per-buddy card |
| `lib/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart` | Capture flow |

## Testing Strategy

### Unit Tests

- `SignatureStorageService` buddy signature methods
- `Signature` entity type/role handling

### Widget Tests

- `BuddySignaturesSection` with signed/unsigned buddies
- `BuddySignatureCard` state transitions
- `BuddySignatureRequestSheet` capture flow

### Integration Tests

- Full flow: Add buddy to dive -> Request signature -> Sign -> View in detail
- PDF export with signatures embedded

## Migration Path

1. Database migration adds nullable `signatureType` column
2. Existing instructor signatures remain functional (null type = instructor)
3. New buddy signatures use `type = 'buddy'`

## Future Considerations

- Remote signature requests (v2 - requires backend)
- Signature verification/tamper detection
- QR code linking for easy buddy onboarding
