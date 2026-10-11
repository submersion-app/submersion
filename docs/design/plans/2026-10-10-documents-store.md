# Documents Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A synced documents store (insurance, medical clearance, certification cards, permits, bookings and more) with any number of embedded pages, owned by the diver or by a dive, site, trip, equipment item, course, certification, buddy or dive center, with expiry chips and notifications.

**Architecture:** Two new synced Drift tables, `documents` and `document_pages` (BLOB, own HLC), behind one `DocumentRepository`. `Diver.insurance` / `Diver.medicalClearanceExpiryDate` and `Certification.photoFront` / `photoBack` stay on their entities as read models: `DiverRepository` and `CertificationRepository` hydrate them from documents and write them to documents, so the emergency card, chips, UDDF export, e-card wallet and PDF export keep working unchanged. A new `features/documents` module holds the domain, repository, providers, pages and the reusable `DocumentsSection` that eight owner detail pages embed.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod 3 (`package:submersion/core/providers/provider.dart`), go_router, `uuid` 4.x (v5 ids), `image_picker` + `encodeStoredImage`, `file_picker` 12 + `materializePickedFiles`, `pdfrx`, `flutter_local_notifications`.

**Spec:** `docs/design/specs/2026-10-10-documents-store-design.md`

## Global Constraints

- Schema version 276 to 277 (`AppDatabase.currentSchemaVersion`), rung added to `migrationVersions`; `minimumCompatibleSchemaVersion` stays 275.
- Tables live in `lib/core/database/tables/document_tables.dart`; never declare a table or rung in `database.dart` beyond the import/export lines, the `@DriftDatabase` list and the version constants.
- Max page size: `10 * 1024 * 1024` bytes after re-encoding. Accepted: camera/gallery images (re-encoded with `ImageEncodeSpec.certificationCard`), files with extensions `pdf`, `doc`, `docx`, `txt`, `jpg`, `jpeg`, `png`, `heic` (picked images also re-encoded).
- Default reminder lead: 30 days (`reminderLeadDays == null`); `0` means off. `certificationCard` never reminds and has no expiry.
- Deterministic ids: UUIDv5 in namespace `kDocumentNamespace = 'c3a5f0d2-8b14-4e6f-9a27-5d0e1b4c7f93'` over `submersion:document:<kind>:<sourceId>`.
- No mirror: nothing writes `divers.insurance_*`, `divers.medical_clearance_expiry_date`, `certifications.photo_front` or `certifications.photo_back` after this change. The columns stay in the schema and in the conflict catalogue.
- Every user-visible string goes through l10n, in `app_en.arb` and all 10 other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- Dates shown through `UnitFormatter(settings).formatDate`. No em dashes in code, comments or strings.
- Paths built with `p.join`; tests that touch process-wide state restore it in `addTearDown`.
- `dart format .`, `flutter analyze`, the task's tests, and `test/architecture/` + `test/shared/` after adding files under `lib/`.

## Review Focus

1. **Second device upgrades after the first already synced migrated rows.** Expect no duplicate insurance, clearance or card documents: same ids, merged. Pinned in Task 2 (two independent upgrades produce identical ids) and Task 4 (round trip of a migrated row).
2. **A diver deletes a migrated document, then the rung's data step runs again.** Expect it not to come back. The data step runs only in the rung, never in `beforeOpen`. Pinned in Task 2 (backstop does not re-create deleted rows).
3. **Deleting a buddy deletes the buddy's certifications inline** (`buddy_repository.dart:363-379`), bypassing `deleteCertification`. Expect their card documents and pages tombstoned too. Pinned in Task 6.
4. **Editing a certification without touching its photos** (rename only). Expect the card pages unchanged, not re-stamped, and no empty card document created for a cert that never had photos. Pinned in Task 8.
5. **A burst of large scans before the next sync.** Expect the changeset writer to fall back to a streamed base rather than build one giant in-memory delta. Pinned in Task 4 (`pendingSeriesBlobBytes` counts `document_pages.bytes`).

---

## File map

Create:

| File | Responsibility |
| --- | --- |
| `lib/features/documents/domain/entities/document.dart` | `Document`, `DocumentType`, `DocumentOwnerKind`, `DocumentOwner` |
| `lib/features/documents/domain/entities/document_page.dart` | `DocumentPage`, `DocumentPageSide` |
| `lib/features/documents/domain/document_expiry.dart` | `DocumentExpiryStatus`, `documentExpiryStatus()` |
| `lib/features/documents/domain/document_ids.dart` | `kDocumentNamespace`, deterministic id functions |
| `lib/features/documents/domain/document_file_gate.dart` | Extension and size gate, mime mapping |
| `lib/core/database/tables/document_tables.dart` | `Documents`, `DocumentPages` Drift tables |
| `lib/core/database/migrations/helpers/document_migrations.dart` | `_assertDocumentsSchema`, `_migrateLegacyDocuments` (part file) |
| `lib/features/documents/data/repositories/document_repository.dart` | CRUD, pages, primary invariant, owner cleanup, queries |
| `lib/features/documents/data/repositories/document_row_mapper.dart` | Row to entity mapping, owner column helpers |
| `lib/features/documents/data/services/document_page_capture.dart` | Camera/gallery/file capture with re-encode and gate |
| `lib/features/documents/presentation/providers/document_providers.dart` | Read providers and `DocumentMutations` |
| `lib/features/documents/presentation/helpers/document_page_opener.dart` | Open a non-renderable page externally |
| `lib/features/documents/presentation/widgets/document_expiry_badge.dart` | Badge from `DocumentExpiryStatus` |
| `lib/features/documents/presentation/widgets/document_tile.dart` | List row: thumbnail, title, owner, badge |
| `lib/features/documents/presentation/widgets/document_page_thumbnail.dart` | First-page thumbnail (image, PDF page 1, file icon) |
| `lib/features/documents/presentation/widgets/document_page_strip.dart` | Editor page strip with Front/Back slots |
| `lib/features/documents/presentation/widgets/document_page_viewer.dart` | Swipe viewer, PDF via pdfrx, file tile |
| `lib/features/documents/presentation/widgets/documents_section.dart` | Owner-page section |
| `lib/features/documents/presentation/widgets/documents_expiring_strip.dart` | Expiring strip on the global page |
| `lib/features/documents/presentation/pages/documents_page.dart` | Global list (master-detail) |
| `lib/features/documents/presentation/pages/document_detail_page.dart` | Detail |
| `lib/features/documents/presentation/pages/document_edit_page.dart` | Editor |
| `lib/features/documents/presentation/document_l10n.dart` | Type/owner-kind labels and icons |
| `lib/features/settings/presentation/conflicts/catalogue/document_fields.dart` | Conflict catalogue for the two tables |

Modify (main ones; each task lists exact lines): `database.dart`, `rungs_v231_onward.dart`, `app_database_migrations.dart`, `before_open_table_backstops.dart`, `sync_data_serializer.dart`, `sync_service.dart`, `sync_repository.dart`, `conflict_reference.dart`, `conflict_reference_labels.dart`, `conflict_field_catalogue.dart`, `diver_repository.dart`, `diver_delete_steps.dart`, `certification_repository.dart`, the eight owner repositories and detail pages, `dive_detail_sections.dart`, `site_detail_sections.dart`, `nav_destinations.dart`, `feature_accent_colors.dart`, `app_router.dart`, `diver_profile_hub_page.dart`, `medical_info_edit_page.dart`, `gauge_providers.dart`, `gauge_strip.dart`, `home_appearance_page.dart`, `notification_service.dart`, `notification_scheduler.dart`, ARB files.

Delete: `lib/features/settings/presentation/pages/insurance_edit_page.dart` and `test/features/settings/presentation/pages/insurance_edit_page_test.dart` (Task 15).

---

### Task 1: Domain model, expiry status, deterministic ids, file gate

**Files:**
- Create: `lib/features/documents/domain/entities/document.dart`
- Create: `lib/features/documents/domain/entities/document_page.dart`
- Create: `lib/features/documents/domain/document_expiry.dart`
- Create: `lib/features/documents/domain/document_ids.dart`
- Create: `lib/features/documents/domain/document_file_gate.dart`
- Test: `test/features/documents/domain/document_expiry_test.dart`, `document_ids_test.dart`, `document_file_gate_test.dart`, `document_entity_test.dart`

**Interfaces:**
- Produces:
  - `enum DocumentType { insurance, medicalClearance, certificationCard, permit, booking, receipt, manual, map, other }` with `static DocumentType fromStorage(String)` (unknown -> `other`) and `String get storage => name`.
  - `enum DocumentOwnerKind { personal, dive, site, trip, equipment, course, certification, buddy, diveCenter }` with `fromStorage` / `storage`.
  - `class DocumentOwner { DocumentOwnerKind kind; String? id; const DocumentOwner.personal(); const DocumentOwner(kind, id); }`
  - `class Document` (fields below), `int get effectiveReminderLeadDays`, `bool get remindsOnExpiry`, `copyWith` with `_unset` sentinel for nullable fields.
  - `class DocumentPage { id, documentId, pageIndex, side, fileName, mimeType, sizeBytes, Uint8List? bytes, createdAt, updatedAt; bool get isImage; bool get isPdf; }`
  - `enum DocumentExpiryKind { none, ok, dueSoon, expired }`, `class DocumentExpiryStatus { kind; int? daysLeft; }`, `DocumentExpiryStatus documentExpiryStatus(Document d, DateTime now)`.
  - `String documentInsuranceId(String diverId)`, `String documentMedicalClearanceId(String diverId)`, `String documentCertificationCardId(String certificationId)`, `String documentCardPageId(String documentId, DocumentPageSide side)`.
  - `const int kMaxDocumentPageBytes`, `sealed class DocumentFileVerdict` with `DocumentFileAccepted(mimeType, needsImageReencode)`, `DocumentFileTooLarge(sizeBytes)`, `DocumentFileUnsupported(extension)`; `DocumentFileVerdict checkDocumentFile({required String fileName, required int sizeBytes})`.

- [ ] **Step 1: Write the failing expiry test**

```dart
// test/features/documents/domain/document_expiry_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

Document doc({
  DocumentType type = DocumentType.insurance,
  DateTime? expiry,
  int? lead,
}) => Document(
  id: 'd1',
  diverId: 'diver',
  owner: const DocumentOwner.personal(),
  type: type,
  expiryDate: expiry,
  reminderLeadDays: lead,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final now = DateTime(2026, 10, 10, 15, 30);

  test('no expiry date is none', () {
    expect(documentExpiryStatus(doc(), now).kind, DocumentExpiryKind.none);
  });

  test('certification card never has a status', () {
    final d = doc(
      type: DocumentType.certificationCard,
      expiry: DateTime(2026, 10, 1),
    );
    expect(documentExpiryStatus(d, now).kind, DocumentExpiryKind.none);
  });

  test('expiry yesterday is expired by one day', () {
    final s = documentExpiryStatus(doc(expiry: DateTime(2026, 10, 9)), now);
    expect(s.kind, DocumentExpiryKind.expired);
    expect(s.daysLeft, -1);
  });

  test('expiry today is due soon with zero days left, not expired', () {
    final s = documentExpiryStatus(doc(expiry: DateTime(2026, 10, 10)), now);
    expect(s.kind, DocumentExpiryKind.dueSoon);
    expect(s.daysLeft, 0);
  });

  test('default lead is 30 days: day 30 is due soon, day 31 is ok', () {
    expect(
      documentExpiryStatus(doc(expiry: DateTime(2026, 11, 9)), now).kind,
      DocumentExpiryKind.dueSoon,
    );
    expect(
      documentExpiryStatus(doc(expiry: DateTime(2026, 11, 10)), now).kind,
      DocumentExpiryKind.ok,
    );
  });

  test('lead 0 never reports due soon but still reports expired', () {
    expect(
      documentExpiryStatus(doc(expiry: DateTime(2026, 10, 11), lead: 0), now)
          .kind,
      DocumentExpiryKind.ok,
    );
    expect(
      documentExpiryStatus(doc(expiry: DateTime(2026, 10, 1), lead: 0), now)
          .kind,
      DocumentExpiryKind.expired,
    );
  });

  test('day counting is calendar based across a DST change', () {
    // Europe and US both change clocks between these dates.
    final march = DateTime(2026, 3, 1, 23, 0);
    final s = documentExpiryStatus(
      doc(expiry: DateTime(2026, 4, 15), lead: 60),
      march,
    );
    expect(s.daysLeft, 45);
  });

  test('day counting across a month end', () {
    final s = documentExpiryStatus(
      doc(expiry: DateTime(2026, 3, 1)),
      DateTime(2026, 2, 27, 8),
    );
    expect(s.daysLeft, 2);
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/features/documents/domain/document_expiry_test.dart`
Expected: FAIL, `document_expiry.dart` and `document.dart` not found.

- [ ] **Step 3: Write the entities**

```dart
// lib/features/documents/domain/entities/document.dart
import 'package:equatable/equatable.dart';

/// What a document is. Only [insurance], [medicalClearance] and
/// [certificationCard] carry behaviour; the rest set the icon and the
/// default title.
enum DocumentType {
  insurance,
  medicalClearance,
  certificationCard,
  permit,
  booking,
  receipt,
  manual,
  map,
  other;

  String get storage => name;

  static DocumentType fromStorage(String? value) => DocumentType.values
      .firstWhere((t) => t.name == value, orElse: () => DocumentType.other);
}

/// The kind of record a document is filed under. [personal] means no
/// owner link: the document belongs to the diver.
enum DocumentOwnerKind {
  personal,
  dive,
  site,
  trip,
  equipment,
  course,
  certification,
  buddy,
  diveCenter;

  String get storage => name;

  static DocumentOwnerKind fromStorage(String? value) =>
      DocumentOwnerKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => DocumentOwnerKind.personal,
      );
}

class DocumentOwner extends Equatable {
  final DocumentOwnerKind kind;

  /// Null exactly when [kind] is [DocumentOwnerKind.personal].
  final String? id;

  const DocumentOwner.personal() : kind = DocumentOwnerKind.personal, id = null;

  const DocumentOwner(this.kind, String this.id)
    : assert(kind != DocumentOwnerKind.personal);

  bool get isPersonal => kind == DocumentOwnerKind.personal;

  @override
  List<Object?> get props => [kind, id];
}

const Object _unset = Object();

class Document extends Equatable {
  /// Default reminder lead when [reminderLeadDays] is null.
  static const int defaultReminderLeadDays = 30;

  final String id;
  final String diverId;
  final DocumentOwner owner;
  final DocumentType type;

  /// Empty renders as the type's localized name.
  final String title;
  final String? issuer;
  final String? referenceNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;

  /// Null means [defaultReminderLeadDays]; 0 means no reminder.
  final int? reminderLeadDays;

  /// Insurance only.
  final String? emergencyPhone;
  final String? phone;
  final bool isPrimary;

  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Document({
    required this.id,
    required this.diverId,
    required this.owner,
    required this.type,
    this.title = '',
    this.issuer,
    this.referenceNumber,
    this.issueDate,
    this.expiryDate,
    this.reminderLeadDays,
    this.emergencyPhone,
    this.phone,
    this.isPrimary = false,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  int get effectiveReminderLeadDays =>
      reminderLeadDays ?? defaultReminderLeadDays;

  /// Whether this document takes part in chips and notifications. A card
  /// document's expiry lives on its certification (currency warnings).
  bool get remindsOnExpiry =>
      type != DocumentType.certificationCard && expiryDate != null;

  Document copyWith({
    String? id,
    String? diverId,
    DocumentOwner? owner,
    DocumentType? type,
    String? title,
    Object? issuer = _unset,
    Object? referenceNumber = _unset,
    Object? issueDate = _unset,
    Object? expiryDate = _unset,
    Object? reminderLeadDays = _unset,
    Object? emergencyPhone = _unset,
    Object? phone = _unset,
    bool? isPrimary,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    T? pick<T>(Object? value, T? current) =>
        identical(value, _unset) ? current : value as T?;
    return Document(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      owner: owner ?? this.owner,
      type: type ?? this.type,
      title: title ?? this.title,
      issuer: pick<String>(issuer, this.issuer),
      referenceNumber: pick<String>(referenceNumber, this.referenceNumber),
      issueDate: pick<DateTime>(issueDate, this.issueDate),
      expiryDate: pick<DateTime>(expiryDate, this.expiryDate),
      reminderLeadDays: pick<int>(reminderLeadDays, this.reminderLeadDays),
      emergencyPhone: pick<String>(emergencyPhone, this.emergencyPhone),
      phone: pick<String>(phone, this.phone),
      isPrimary: isPrimary ?? this.isPrimary,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    owner,
    type,
    title,
    issuer,
    referenceNumber,
    issueDate,
    expiryDate,
    reminderLeadDays,
    emergencyPhone,
    phone,
    isPrimary,
    notes,
    createdAt,
    updatedAt,
  ];
}
```

```dart
// lib/features/documents/domain/entities/document_page.dart
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

enum DocumentPageSide {
  front,
  back;

  static DocumentPageSide? fromStorage(String? value) => switch (value) {
    'front' => DocumentPageSide.front,
    'back' => DocumentPageSide.back,
    _ => null,
  };
}

class DocumentPage extends Equatable {
  /// Empty for a page not yet saved.
  final String id;
  final String documentId;
  final int pageIndex;
  final DocumentPageSide? side;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Null when loaded metadata-only.
  final Uint8List? bytes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentPage({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    this.side,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.bytes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  DocumentPage copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    DocumentPageSide? side,
    bool clearSide = false,
    Uint8List? bytes,
    DateTime? updatedAt,
  }) => DocumentPage(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    pageIndex: pageIndex ?? this.pageIndex,
    side: clearSide ? null : (side ?? this.side),
    fileName: fileName,
    mimeType: mimeType,
    sizeBytes: sizeBytes,
    bytes: bytes ?? this.bytes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  // bytes left out: equality by identity of content would hash megabytes.
  @override
  List<Object?> get props => [
    id,
    documentId,
    pageIndex,
    side,
    fileName,
    mimeType,
    sizeBytes,
    createdAt,
    updatedAt,
  ];
}
```

- [ ] **Step 4: Write `documentExpiryStatus`**

```dart
// lib/features/documents/domain/document_expiry.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';

enum DocumentExpiryKind { none, ok, dueSoon, expired }

class DocumentExpiryStatus extends Equatable {
  final DocumentExpiryKind kind;

  /// Calendar days from today to the expiry day; negative once expired.
  /// Null for [DocumentExpiryKind.none].
  final int? daysLeft;

  const DocumentExpiryStatus(this.kind, this.daysLeft);

  static const none = DocumentExpiryStatus(DocumentExpiryKind.none, null);

  bool get needsAttention =>
      kind == DocumentExpiryKind.dueSoon || kind == DocumentExpiryKind.expired;

  @override
  List<Object?> get props => [kind, daysLeft];
}

/// The one rule chips, badges and the notification scheduler share.
///
/// Days are counted between calendar dates in UTC, so a DST change between
/// [now] and the expiry cannot shift the count by an hour into the wrong
/// day. The expiry day itself is "due, 0 days left", not expired.
DocumentExpiryStatus documentExpiryStatus(Document document, DateTime now) {
  final expiry = document.expiryDate;
  if (!document.remindsOnExpiry || expiry == null) {
    return DocumentExpiryStatus.none;
  }
  final today = DateTime.utc(now.year, now.month, now.day);
  final expiryDay = DateTime.utc(expiry.year, expiry.month, expiry.day);
  final daysLeft = expiryDay.difference(today).inDays;
  if (daysLeft < 0) {
    return DocumentExpiryStatus(DocumentExpiryKind.expired, daysLeft);
  }
  final lead = document.effectiveReminderLeadDays;
  if (lead > 0 && daysLeft <= lead) {
    return DocumentExpiryStatus(DocumentExpiryKind.dueSoon, daysLeft);
  }
  return DocumentExpiryStatus(DocumentExpiryKind.ok, daysLeft);
}
```

- [ ] **Step 5: Run the expiry test, expect PASS**

Run: `flutter test test/features/documents/domain/document_expiry_test.dart`

- [ ] **Step 6: Write the failing id and gate tests**

```dart
// test/features/documents/domain/document_ids_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

void main() {
  test('ids are stable for the same source', () {
    expect(documentInsuranceId('d1'), documentInsuranceId('d1'));
    expect(
      documentCertificationCardId('c1'),
      documentCertificationCardId('c1'),
    );
  });

  test('ids differ by kind and by source', () {
    final ids = {
      documentInsuranceId('d1'),
      documentInsuranceId('d2'),
      documentMedicalClearanceId('d1'),
      documentCertificationCardId('d1'),
    };
    expect(ids, hasLength(4));
  });

  test('card page ids differ by side', () {
    final doc = documentCertificationCardId('c1');
    expect(
      documentCardPageId(doc, DocumentPageSide.front),
      isNot(documentCardPageId(doc, DocumentPageSide.back)),
    );
  });

  test('pinned value so a namespace edit cannot slip through', () {
    // Recompute once with the uuid package if the namespace is ever
    // changed on purpose; it must never change after release.
    expect(documentInsuranceId('d1'), hasLength(36));
    expect(documentInsuranceId('d1')[14], '5'); // UUID version 5
  });
}
```

```dart
// test/features/documents/domain/document_file_gate_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_file_gate.dart';

void main() {
  test('pdf, word and text are accepted as-is', () {
    for (final (name, mime) in [
      ('a.pdf', 'application/pdf'),
      ('a.DOC', 'application/msword'),
      (
        'a.docx',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      ('a.txt', 'text/plain'),
    ]) {
      final v = checkDocumentFile(fileName: name, sizeBytes: 10);
      expect(v, isA<DocumentFileAccepted>(), reason: name);
      v as DocumentFileAccepted;
      expect(v.mimeType, mime);
      expect(v.needsImageReencode, isFalse);
    }
  });

  test('picked images are accepted and re-encoded', () {
    final v = checkDocumentFile(fileName: 'scan.HEIC', sizeBytes: 10);
    expect((v as DocumentFileAccepted).needsImageReencode, isTrue);
  });

  test('exactly 10 MB is accepted, one byte more is refused', () {
    expect(
      checkDocumentFile(fileName: 'a.pdf', sizeBytes: kMaxDocumentPageBytes),
      isA<DocumentFileAccepted>(),
    );
    expect(
      checkDocumentFile(
        fileName: 'a.pdf',
        sizeBytes: kMaxDocumentPageBytes + 1,
      ),
      isA<DocumentFileTooLarge>(),
    );
  });

  test('other extensions and no extension are refused', () {
    expect(
      checkDocumentFile(fileName: 'a.gpx', sizeBytes: 1),
      isA<DocumentFileUnsupported>(),
    );
    expect(
      checkDocumentFile(fileName: 'README', sizeBytes: 1),
      isA<DocumentFileUnsupported>(),
    );
  });
}
```

- [ ] **Step 7: Run them, expect FAIL** (missing files)

Run: `flutter test test/features/documents/domain/`

- [ ] **Step 8: Implement ids and gate**

```dart
// lib/features/documents/domain/document_ids.dart
import 'package:uuid/uuid.dart';

import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// Fixed namespace for document ids derived from their source rows. Two
/// devices that migrate the same library independently produce the same
/// ids, so the rows merge by id instead of duplicating. Never change it.
const String kDocumentNamespace = 'c3a5f0d2-8b14-4e6f-9a27-5d0e1b4c7f93';

String _v5(String key) =>
    const Uuid().v5(kDocumentNamespace, 'submersion:document:$key');

String documentInsuranceId(String diverId) => _v5('insurance:$diverId');

String documentMedicalClearanceId(String diverId) =>
    _v5('medicalClearance:$diverId');

String documentCertificationCardId(String certificationId) =>
    _v5('certificationCard:$certificationId');

String documentCardPageId(String documentId, DocumentPageSide side) =>
    _v5('page:$documentId:${side.name}');
```

```dart
// lib/features/documents/domain/document_file_gate.dart
import 'package:path/path.dart' as p;

/// Largest page the store accepts, after any image re-encode.
const int kMaxDocumentPageBytes = 10 * 1024 * 1024;

const Map<String, String> _fileMimeTypes = {
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
};

const Set<String> _imageExtensions = {'jpg', 'jpeg', 'png', 'heic'};

/// Extensions offered by the file picker.
const List<String> kDocumentPickerExtensions = [
  'pdf',
  'doc',
  'docx',
  'txt',
  'jpg',
  'jpeg',
  'png',
  'heic',
];

sealed class DocumentFileVerdict {
  const DocumentFileVerdict();
}

class DocumentFileAccepted extends DocumentFileVerdict {
  final String mimeType;

  /// Images are re-encoded like certification photos; the stored mime is
  /// then image/jpeg.
  final bool needsImageReencode;
  const DocumentFileAccepted(this.mimeType, {this.needsImageReencode = false});
}

class DocumentFileTooLarge extends DocumentFileVerdict {
  final int sizeBytes;
  const DocumentFileTooLarge(this.sizeBytes);
}

class DocumentFileUnsupported extends DocumentFileVerdict {
  final String extension;
  const DocumentFileUnsupported(this.extension);
}

DocumentFileVerdict checkDocumentFile({
  required String fileName,
  required int sizeBytes,
}) {
  final ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
  if (_imageExtensions.contains(ext)) {
    // Size is checked again after the re-encode shrinks it.
    return const DocumentFileAccepted('image/jpeg', needsImageReencode: true);
  }
  final mime = _fileMimeTypes[ext];
  if (mime == null) return DocumentFileUnsupported(ext);
  if (sizeBytes > kMaxDocumentPageBytes) return DocumentFileTooLarge(sizeBytes);
  return DocumentFileAccepted(mime);
}
```

- [ ] **Step 9: Add an entity test for `copyWith` clearing and owner invariants**

```dart
// test/features/documents/domain/document_entity_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';

void main() {
  final base = Document(
    id: 'a',
    diverId: 'd',
    owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    type: DocumentType.permit,
    expiryDate: DateTime(2027),
    issuer: 'Park',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('copyWith can clear a nullable field', () {
    final cleared = base.copyWith(expiryDate: null, issuer: null);
    expect(cleared.expiryDate, isNull);
    expect(cleared.issuer, isNull);
  });

  test('copyWith without arguments keeps nullable fields', () {
    expect(base.copyWith(), base);
  });

  test('effective lead defaults to 30', () {
    expect(base.effectiveReminderLeadDays, 30);
    expect(base.copyWith(reminderLeadDays: 0).effectiveReminderLeadDays, 0);
  });

  test('storage round trip, unknown falls back', () {
    for (final t in DocumentType.values) {
      expect(DocumentType.fromStorage(t.storage), t);
    }
    expect(DocumentType.fromStorage('nope'), DocumentType.other);
    expect(DocumentOwnerKind.fromStorage(null), DocumentOwnerKind.personal);
  });
}
```

- [ ] **Step 10: Run all domain tests, expect PASS; analyze**

Run: `flutter test test/features/documents/domain/ && flutter analyze lib/features/documents`

- [ ] **Step 11: Commit**

```bash
git add lib/features/documents/domain test/features/documents/domain
git commit -m "feat(documents): domain model, expiry status, ids and file gate"
```

---

### Task 2: Tables, rung v277, legacy migration, beforeOpen backstop

**Files:**
- Create: `lib/core/database/tables/document_tables.dart`
- Create: `lib/core/database/migrations/helpers/document_migrations.dart`
- Modify: `lib/core/database/database.dart:4-61` (import + export), `:83-245` (table list), `:256` (version 277), `:1180` (append `277,`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart:33-71` (add `part 'helpers/document_migrations.dart';`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart:309` (rung)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` (end of `_tableBackstopsFromV217`)
- Test: `test/core/database/migration_v277_documents_test.dart`

**Interfaces:**
- Consumes: Task 1 id functions.
- Produces: Drift classes `Documents` (`DocumentRow`, `DocumentsCompanion`), `DocumentPages` (`DocumentPageRow`, `DocumentPagesCompanion`); `db.documents`, `db.documentPages`; SQL tables `documents`, `document_pages`.

- [ ] **Step 1: Write the table file**

```dart
// lib/core/database/tables/document_tables.dart
/// Documents: a diver's papers with optional expiry, and their pages.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/buddy_tables.dart';
import 'package:submersion/core/database/tables/dive_tables.dart';
import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';
import 'package:submersion/core/database/tables/site_tables.dart';
import 'package:submersion/core/database/tables/trip_tables.dart';

/// One document (issue #2613). At most one owner link is set; none means a
/// personal document. Owner links use SET NULL only as a safety net: every
/// owner's delete path calls DocumentRepository.deleteForOwner, which
/// deletes and tombstones the documents first.
@DataClassName('DocumentRow')
class Documents extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  TextColumn get diveId => text().nullable().references(
    Dives,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get siteId => text().nullable().references(
    DiveSites,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get tripId => text().nullable().references(
    Trips,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get courseId => text().nullable().references(
    Courses,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get certificationId => text().nullable().references(
    Certifications,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get buddyId => text().nullable().references(
    Buddies,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get diveCenterId => text().nullable().references(
    DiveCenters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get type => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get issuer => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  IntColumn get issueDate => integer().nullable()();
  IntColumn get expiryDate => integer().nullable()();
  IntColumn get reminderLeadDays => integer().nullable()();
  TextColumn get emergencyPhone => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution. Rows the
  /// v277 migration creates carry none, so any later edit wins.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One page of a document: an embedded file, synced with the row.
@DataClassName('DocumentPageRow')
class DocumentPages extends Table {
  TextColumn get id => text()();
  TextColumn get documentId =>
      text().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get pageIndex => integer()();

  /// 'front' or 'back' for card types; null otherwise.
  TextColumn get side => text().nullable()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  BlobColumn get bytes => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// This page's own clock: exported on it, so a stale page from a peer
  /// cannot overwrite a newer one (the diveProfileSeries pattern).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Before writing, confirm the class names: `grep -n "^class \(Dives\|DiveSites\|Trips\|Equipment\|Courses\|Buddies\|DiveCenters\) extends Table" lib/core/database/tables/*.dart` and fix the imports to the files it reports.

- [ ] **Step 2: Register in `database.dart`**

Add next to the other table imports and exports (`:4-61`):

```dart
import 'package:submersion/core/database/tables/document_tables.dart';
```

```dart
export 'package:submersion/core/database/tables/document_tables.dart';
```

Append to the `@DriftDatabase(tables: [...])` list after `CertificationCurrencyEvents,`:

```dart
    // Documents store (v277, issue #2613)
    Documents,
    DocumentPages,
```

Set `static const int currentSchemaVersion = 277;` and append to `migrationVersions` after `276,`:

```dart
    // v277: documents and document_pages; insurance, medical clearance and
    // certification card photos copied in (issue #2613).
    277,
```

- [ ] **Step 3: Run codegen**

Run: `bash scripts/setup.sh` (it runs build_runner; a bare `dart run build_runner build` is blocked by a deny rule in this environment).
Expected: completes; `database.g.dart` has `$DocumentsTable`.

- [ ] **Step 4: Write the failing migration test**

```dart
// test/core/database/migration_v277_documents_test.dart
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';

const _parents = [
  'CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, '
      'is_default INTEGER NOT NULL DEFAULT 0, '
      'medical_clearance_expiry_date INTEGER, insurance_provider TEXT, '
      'insurance_policy_number TEXT, insurance_expiry_date INTEGER, '
      'insurance_emergency_phone TEXT, insurance_phone TEXT, '
      'created_at INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0)',
  'CREATE TABLE buddies (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT)',
  'CREATE TABLE certifications (id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
      'buddy_id TEXT, photo_front BLOB, photo_back BLOB)',
  'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE courses (id TEXT NOT NULL PRIMARY KEY)',
  'CREATE TABLE dive_centers (id TEXT NOT NULL PRIMARY KEY)',
];

NativeDatabase seeded() => NativeDatabase.memory(
  setup: (raw) {
    raw.execute('PRAGMA user_version = 276');
    for (final sql in _parents) {
      raw.execute(sql);
    }
    raw.execute(
      "INSERT INTO divers (id, name, is_default, insurance_provider, "
      "insurance_policy_number, insurance_expiry_date, "
      "insurance_emergency_phone, insurance_phone, "
      "medical_clearance_expiry_date) VALUES "
      "('d1', 'Ana', 1, 'DAN Europe', 'P-1', 1800000000000, '+1 911', "
      "'+1 555', 1790000000000)",
    );
    raw.execute("INSERT INTO divers (id, name) VALUES ('d2', 'Ben')");
    raw.execute("INSERT INTO buddies (id, diver_id) VALUES ('b1', 'd2')");
    raw.execute(
      "INSERT INTO certifications (id, diver_id, photo_front, photo_back) "
      "VALUES ('c1', 'd1', X'0102', X'0304')",
    );
    raw.execute(
      "INSERT INTO certifications (id, buddy_id, photo_front) "
      "VALUES ('c2', 'b1', X'0506')",
    );
    raw.execute(
      "INSERT INTO certifications (id, photo_back) VALUES ('c3', X'0708')",
    );
    raw.execute("INSERT INTO certifications (id, diver_id) VALUES ('c4', 'd1')");
  },
);

Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async =>
    [for (final r in await db.customSelect(sql).get()) r.data];

void main() {
  test('v277 is in the ladder and did not move the sync floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(277));
    expect(AppDatabase.migrationVersions, contains(277));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(277));
  });

  test('insurance becomes a primary insurance document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT * FROM documents WHERE type = 'insurance'",
    );
    expect(r, hasLength(1));
    expect(r.single['id'], documentInsuranceId('d1'));
    expect(r.single['diver_id'], 'd1');
    expect(r.single['issuer'], 'DAN Europe');
    expect(r.single['reference_number'], 'P-1');
    expect(r.single['expiry_date'], 1800000000000);
    expect(r.single['emergency_phone'], '+1 911');
    expect(r.single['phone'], '+1 555');
    expect(r.single['is_primary'], 1);
    expect(r.single['hlc'], isNull);
  });

  test('clearance becomes a medical clearance document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT * FROM documents WHERE type = 'medicalClearance'",
    );
    expect(r.single['id'], documentMedicalClearanceId('d1'));
    expect(r.single['expiry_date'], 1790000000000);
  });

  test('a diver with nothing to move gets no document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT * FROM documents WHERE diver_id = 'd2' AND type != 'certificationCard'",
    );
    expect(r, isEmpty);
  });

  test('cert photos become card documents with front and back pages', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final docs = await rows(
      db,
      "SELECT id, diver_id, certification_id FROM documents "
      "WHERE type = 'certificationCard' ORDER BY certification_id",
    );
    expect([for (final d in docs) d['certification_id']], ['c1', 'c2', 'c3']);
    // c2 is a buddy's cert: filed under the diver who owns that buddy.
    expect(docs[1]['diver_id'], 'd2');
    // c3 is ownerless: filed under the default diver.
    expect(docs[2]['diver_id'], 'd1');
    final pages = await rows(
      db,
      "SELECT side, bytes, mime_type, page_index FROM document_pages "
      "WHERE document_id = '${documentCertificationCardId('c1')}' "
      "ORDER BY page_index",
    );
    expect([for (final p in pages) p['side']], ['front', 'back']);
    expect(pages[0]['bytes'], Uint8List.fromList([1, 2]));
    expect(pages[0]['mime_type'], 'image/jpeg');
  });

  test('a cert with no photos gets no card document', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final r = await rows(
      db,
      "SELECT id FROM documents WHERE certification_id = 'c4'",
    );
    expect(r, isEmpty);
  });

  test('old columns are left untouched', () async {
    final db = AppDatabase(seeded());
    addTearDown(db.close);
    final d = await rows(
      db,
      "SELECT insurance_provider FROM divers WHERE id = 'd1'",
    );
    expect(d.single['insurance_provider'], 'DAN Europe');
    final c = await rows(
      db,
      "SELECT photo_front FROM certifications WHERE id = 'c1'",
    );
    expect(c.single['photo_front'], isNotNull);
  });

  test('two independent upgrades produce identical ids', () async {
    final a = AppDatabase(seeded());
    final b = AppDatabase(seeded());
    addTearDown(a.close);
    addTearDown(b.close);
    const sql = 'SELECT id FROM documents UNION ALL '
        'SELECT id FROM document_pages ORDER BY 1';
    expect(await rows(a, sql), await rows(b, sql));
  });

  test('beforeOpen does not re-create a deleted migrated document', () async {
    final raw = seeded();
    final db = AppDatabase(raw);
    await db.customStatement(
      "DELETE FROM documents WHERE id = '${documentInsuranceId('d1')}'",
    );
    // Re-open runs beforeOpen again on the same connection.
    await db.close();
    final reopened = AppDatabase(raw);
    addTearDown(reopened.close);
    final r = await rows(
      reopened,
      "SELECT id FROM documents WHERE type = 'insurance'",
    );
    expect(r, isEmpty);
  });
}
```

Note on the last test: if `NativeDatabase.memory` does not survive `close()`, use `NativeDatabase(File(p.join(tempDir.path, 'v277.db')), setup: ...)` with `Directory.systemTemp.createTempSync()` and delete it in `addTearDown`.

- [ ] **Step 5: Run it, expect FAIL** (tables absent)

Run: `flutter test test/core/database/migration_v277_documents_test.dart`

- [ ] **Step 6: Write the migration helper (part file)**

```dart
// lib/core/database/migrations/helpers/document_migrations.dart
part of '../app_database_migrations.dart';

extension DocumentMigrations on AppDatabase {
  /// Creates the documents tables and indexes. Idempotent; also the
  /// beforeOpen backstop. Never copies data.
  Future<void> _assertDocumentsSchema() async {
    for (final parent in const [
      'divers',
      'dives',
      'dive_sites',
      'trips',
      'equipment',
      'courses',
      'certifications',
      'buddies',
      'dive_centers',
    ]) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(documents);
    await Migrator(this).createTable(documentPages);
    for (final column in const [
      'diver_id',
      'dive_id',
      'site_id',
      'trip_id',
      'equipment_id',
      'course_id',
      'certification_id',
      'buddy_id',
      'dive_center_id',
    ]) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_documents_$column '
        'ON documents($column)',
      );
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_document_pages_document '
      'ON document_pages(document_id, page_index)',
    );
  }

  /// v277 data step: copies insurance, medical clearance and certification
  /// card photos into documents. Runs ONLY in the rung: a beforeOpen run
  /// would resurrect a migrated document the diver later deleted. Ids are
  /// deterministic and inserts are OR IGNORE, so a second device that
  /// upgrades the same library produces the same rows.
  Future<void> _migrateLegacyDocuments() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final divers = await customSelect(
      'SELECT id, is_default, insurance_provider, insurance_policy_number, '
      'insurance_expiry_date, insurance_emergency_phone, insurance_phone, '
      'medical_clearance_expiry_date FROM divers ORDER BY created_at, id',
    ).get();
    if (divers.isEmpty) return;

    String? present(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();

    for (final d in divers) {
      final diverId = d.read<String>('id');
      final provider = present(d.readNullable<String>('insurance_provider'));
      final policy = present(d.readNullable<String>('insurance_policy_number'));
      final expiry = d.readNullable<int>('insurance_expiry_date');
      final emergency = present(
        d.readNullable<String>('insurance_emergency_phone'),
      );
      final phone = present(d.readNullable<String>('insurance_phone'));
      if (provider != null ||
          policy != null ||
          expiry != null ||
          emergency != null ||
          phone != null) {
        await customStatement(
          'INSERT OR IGNORE INTO documents (id, diver_id, type, title, '
          'issuer, reference_number, expiry_date, emergency_phone, phone, '
          'is_primary, notes, created_at, updated_at) '
          "VALUES (?, ?, 'insurance', '', ?, ?, ?, ?, ?, 1, '', ?, ?)",
          [
            documentInsuranceId(diverId),
            diverId,
            provider,
            policy,
            expiry,
            emergency,
            phone,
            now,
            now,
          ],
        );
      }
      final clearance = d.readNullable<int>('medical_clearance_expiry_date');
      if (clearance != null) {
        await customStatement(
          'INSERT OR IGNORE INTO documents (id, diver_id, type, title, '
          'expiry_date, is_primary, notes, created_at, updated_at) '
          "VALUES (?, ?, 'medicalClearance', '', ?, 0, '', ?, ?)",
          [documentMedicalClearanceId(diverId), diverId, clearance, now, now],
        );
      }
    }

    final defaultDiverId = (divers.firstWhere(
      (d) => d.read<bool>('is_default'),
      orElse: () => divers.first,
    )).read<String>('id');

    final certs = await customSelect(
      'SELECT c.id, c.diver_id, c.photo_front, c.photo_back, '
      'b.diver_id AS buddy_diver_id FROM certifications c '
      'LEFT JOIN buddies b ON b.id = c.buddy_id '
      'WHERE c.photo_front IS NOT NULL OR c.photo_back IS NOT NULL',
    ).get();
    for (final c in certs) {
      final certId = c.read<String>('id');
      final diverId =
          c.readNullable<String>('diver_id') ??
          c.readNullable<String>('buddy_diver_id') ??
          defaultDiverId;
      final docId = documentCertificationCardId(certId);
      await customStatement(
        'INSERT OR IGNORE INTO documents (id, diver_id, certification_id, '
        'type, title, is_primary, notes, created_at, updated_at) '
        "VALUES (?, ?, ?, 'certificationCard', '', 0, '', ?, ?)",
        [docId, diverId, certId, now, now],
      );
      var index = 0;
      for (final (side, column) in const [
        (DocumentPageSide.front, 'photo_front'),
        (DocumentPageSide.back, 'photo_back'),
      ]) {
        final bytes = c.readNullable<Uint8List>(column);
        if (bytes == null) continue;
        await customStatement(
          'INSERT OR IGNORE INTO document_pages (id, document_id, page_index, '
          'side, file_name, mime_type, size_bytes, bytes, created_at, '
          'updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            documentCardPageId(docId, side),
            docId,
            index++,
            side.name,
            '${side.name}.jpg',
            'image/jpeg',
            bytes.length,
            bytes,
            now,
            now,
          ],
        );
      }
    }
  }
}
```

Add `part 'helpers/document_migrations.dart';` to `app_database_migrations.dart` next to the other `part` lines, and add these imports to `app_database_migrations.dart` if not already present (part files share the library's imports):

```dart
import 'dart:typed_data';

import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
```

Check `test/architecture/` afterwards: if a guard forbids `lib/core` importing `lib/features`, move `document_ids.dart` and `DocumentPageSide` to `lib/core/database/document_identity.dart` (the precedent is `lib/core/database/dive_computer_gear_identity.dart`) and re-export them from the features path.

- [ ] **Step 7: Add the rung**

In `rungs_v231_onward.dart`, after the v276 block:

```dart
    // v277: documents store (issue #2613). Tables re-asserted in
    // beforeOpen; the data copy runs here only, never on open.
    if (from < 277) {
      await _assertDocumentsSchema();
      await _migrateLegacyDocuments();
    }
    if (from < 277) await reportProgress();
```

- [ ] **Step 8: Add the beforeOpen backstop**

At the end of `_tableBackstopsFromV217()` in `before_open_table_backstops.dart`:

```dart
    // v277 backstop: the documents tables (parallel-branch version
    // collision self-heal; idempotent, schema only, never data).
    await _assertDocumentsSchema();
```

- [ ] **Step 9: Run the migration test and the database suite**

Run: `flutter test test/core/database/migration_v277_documents_test.dart test/core/database/`
Expected: PASS. Fix any table-list guard (`database_table_libraries_test.dart`) by keeping the tables in `document_tables.dart`.

- [ ] **Step 10: Commit**

```bash
git add lib/core/database test/core/database/migration_v277_documents_test.dart
git commit -m "feat(documents): documents tables and v277 migration"
```

---

### Task 3: DocumentRepository

**Files:**
- Create: `lib/features/documents/data/repositories/document_row_mapper.dart`
- Create: `lib/features/documents/data/repositories/document_repository.dart`
- Test: `test/features/documents/data/repositories/document_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 entities and ids; Task 2 tables.
- Produces (`DocumentRepository`):
  - `Stream<void> watchChanges()` (documents + document_pages)
  - `Future<Document?> getById(String id)`
  - `Future<List<Document>> getForOwner(DocumentOwner owner, {String? diverId})`
  - `Future<List<DocumentListEntry>> getAllForDiver(String diverId)` where `class DocumentListEntry { Document document; String? ownerLabel; int pageCount; }`
  - `Future<List<DocumentPage>> getPages(String documentId, {bool withBytes = true})`
  - `Future<DocumentPage?> getFirstPage(String documentId)`
  - `Future<Document> save(Document document, List<DocumentPage> pages)`
  - `Future<void> delete(String id)`
  - `Future<void> deleteForOwner(DocumentOwnerKind kind, String ownerId)`
  - `Future<void> deleteForOwners(DocumentOwnerKind kind, List<String> ownerIds)`
  - `Future<Map<String, Document>> primaryInsuranceByDiver({String? diverId})`
  - `Future<Map<String, DateTime>> latestClearanceExpiryByDiver({String? diverId})`
  - `Future<Map<String, ({Uint8List? front, Uint8List? back})>> cardImagesFor(List<String> certificationIds)`
  - `Future<void> saveCardImages({required String certificationId, required String diverId, required Uint8List? front, required Uint8List? back})`
  - `Future<List<Document>> getRemindingForDiver(String diverId)` (expiry set, not card type)

- [ ] **Step 1: Write the failing repository tests**

```dart
// test/features/documents/data/repositories/document_repository_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../../helpers/test_database.dart';

Document newDoc({
  String id = '',
  DocumentOwner owner = const DocumentOwner.personal(),
  DocumentType type = DocumentType.other,
  bool primary = false,
  DateTime? expiry,
}) => Document(
  id: id,
  diverId: 'd1',
  owner: owner,
  type: type,
  isPrimary: primary,
  expiryDate: expiry,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DocumentPage page(int index, List<int> bytes, {DocumentPageSide? side}) =>
    DocumentPage(
      id: '',
      documentId: '',
      pageIndex: index,
      side: side,
      fileName: 'p$index.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      bytes: Uint8List.fromList(bytes),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<int> tombstones(AppDatabase db, String entity) async => (await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
          variables: [Variable.withString(entity)],
        )
        .getSingle())
    .read<int>('n');

void main() {
  late AppDatabase db;
  late DocumentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DocumentRepository();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO trips (id, diver_id, name, start_date, end_date, "
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('save creates a document with ordered pages and marks them pending',
      () async {
    final saved = await repo.save(newDoc(), [page(0, [1]), page(1, [2])]);
    expect(saved.id, isNotEmpty);
    final pages = await repo.getPages(saved.id);
    expect([for (final p in pages) p.bytes!.first], [1, 2]);
    final pending = await db
        .customSelect(
          "SELECT entity_type FROM sync_records WHERE sync_status = 'pending'",
        )
        .get();
    expect(
      pending.map((r) => r.read<String>('entity_type')).toSet(),
      containsAll(['documents', 'documentPages']),
    );
  });

  test('save reorders, keeps and removes pages; removed ones are tombstoned',
      () async {
    final saved = await repo.save(newDoc(), [page(0, [1]), page(1, [2])]);
    final pages = await repo.getPages(saved.id);
    await repo.save(saved, [pages[1].copyWith(pageIndex: 0)]);
    final after = await repo.getPages(saved.id);
    expect(after.single.id, pages[1].id);
    expect(after.single.pageIndex, 0);
    expect(await tombstones(db, 'documentPages'), 1);
  });

  test('only one primary insurance per diver', () async {
    final a = await repo.save(
      newDoc(type: DocumentType.insurance, primary: true),
      const [],
    );
    await repo.save(
      newDoc(type: DocumentType.insurance, primary: true),
      const [],
    );
    expect((await repo.getById(a.id))!.isPrimary, isFalse);
    final primaries = await repo.primaryInsuranceByDiver();
    expect(primaries.keys, ['d1']);
  });

  test('two primaries from a sync merge resolve to the newest', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (id, at) in [('x', now - 1000), ('y', now)]) {
      await db.customStatement(
        "INSERT INTO documents (id, diver_id, type, is_primary, created_at, "
        "updated_at) VALUES ('$id', 'd1', 'insurance', 1, 0, $at)",
      );
    }
    expect((await repo.primaryInsuranceByDiver())['d1']!.id, 'y');
  });

  test('deleteForOwner removes and tombstones documents and pages', () async {
    await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      [page(0, [1])],
    );
    await repo.deleteForOwner(DocumentOwnerKind.trip, 't1');
    expect(
      await repo.getForOwner(const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      isEmpty,
    );
    expect(await tombstones(db, 'documents'), 1);
    expect(await tombstones(db, 'documentPages'), 1);
  });

  test('delete tombstones the document and its pages', () async {
    final saved = await repo.save(newDoc(), [page(0, [1]), page(1, [2])]);
    await repo.delete(saved.id);
    expect(await repo.getById(saved.id), isNull);
    expect(await tombstones(db, 'documentPages'), 2);
  });

  test('getAllForDiver labels the owner', () async {
    await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      const [],
    );
    final all = await repo.getAllForDiver('d1');
    expect(all.single.ownerLabel, 'Bonaire');
  });

  test('card images: save, read, clear one side, clear both', () async {
    await db.customStatement(
      "INSERT INTO certifications (id, diver_id, name, agency, created_at, "
      "updated_at) VALUES ('c1', 'd1', 'OW', 'padi', 0, 0)",
    );
    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([1]),
      back: Uint8List.fromList([2]),
    );
    var images = await repo.cardImagesFor(['c1']);
    expect(images['c1']!.front, [1]);
    expect(images['c1']!.back, [2]);
    final docId = documentCertificationCardId('c1');
    expect((await repo.getById(docId))!.type, DocumentType.certificationCard);

    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([1]),
      back: null,
    );
    images = await repo.cardImagesFor(['c1']);
    expect(images['c1']!.back, isNull);

    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: null,
      back: null,
    );
    expect(await repo.getById(docId), isNull);
  });

  test('saveCardImages with unchanged bytes writes nothing', () async {
    await db.customStatement(
      "INSERT INTO certifications (id, diver_id, name, agency, created_at, "
      "updated_at) VALUES ('c1', 'd1', 'OW', 'padi', 0, 0)",
    );
    final bytes = Uint8List.fromList([9, 9]);
    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: bytes,
      back: null,
    );
    await db.customStatement('DELETE FROM sync_records');
    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([9, 9]),
      back: null,
    );
    final pending = await db.customSelect('SELECT * FROM sync_records').get();
    expect(pending, isEmpty);
  });

  test('saveCardImages with no images and no card writes nothing', () async {
    await repo.saveCardImages(
      certificationId: 'c9',
      diverId: 'd1',
      front: null,
      back: null,
    );
    expect(await repo.getById(documentCertificationCardId('c9')), isNull);
  });

  test('reminding documents exclude cards and undated ones', () async {
    await repo.save(newDoc(expiry: DateTime(2027)), const []);
    await repo.save(newDoc(), const []);
    expect(await repo.getRemindingForDiver('d1'), hasLength(1));
  });
}
```

Adjust the seeded `trips` / `certifications` columns to the real NOT NULL columns if the insert fails (`grep -n "class Trips" -A20 lib/core/database/tables/trip_tables.dart`).

- [ ] **Step 2: Run, expect FAIL** (repository missing)

Run: `flutter test test/features/documents/data/repositories/document_repository_test.dart`

- [ ] **Step 3: Write the row mapper**

```dart
// lib/features/documents/data/repositories/document_row_mapper.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// SQL column for each non-personal owner kind.
const Map<DocumentOwnerKind, String> kDocumentOwnerColumns = {
  DocumentOwnerKind.dive: 'dive_id',
  DocumentOwnerKind.site: 'site_id',
  DocumentOwnerKind.trip: 'trip_id',
  DocumentOwnerKind.equipment: 'equipment_id',
  DocumentOwnerKind.course: 'course_id',
  DocumentOwnerKind.certification: 'certification_id',
  DocumentOwnerKind.buddy: 'buddy_id',
  DocumentOwnerKind.diveCenter: 'dive_center_id',
};

DateTime? _date(int? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

DocumentOwner ownerOfRow(DocumentRow r) {
  final links = <DocumentOwnerKind, String?>{
    DocumentOwnerKind.dive: r.diveId,
    DocumentOwnerKind.site: r.siteId,
    DocumentOwnerKind.trip: r.tripId,
    DocumentOwnerKind.equipment: r.equipmentId,
    DocumentOwnerKind.course: r.courseId,
    DocumentOwnerKind.certification: r.certificationId,
    DocumentOwnerKind.buddy: r.buddyId,
    DocumentOwnerKind.diveCenter: r.diveCenterId,
  };
  for (final e in links.entries) {
    if (e.value != null) return DocumentOwner(e.key, e.value!);
  }
  return const DocumentOwner.personal();
}

Document documentFromRow(DocumentRow r) => Document(
  id: r.id,
  diverId: r.diverId,
  owner: ownerOfRow(r),
  type: DocumentType.fromStorage(r.type),
  title: r.title,
  issuer: r.issuer,
  referenceNumber: r.referenceNumber,
  issueDate: _date(r.issueDate),
  expiryDate: _date(r.expiryDate),
  reminderLeadDays: r.reminderLeadDays,
  emergencyPhone: r.emergencyPhone,
  phone: r.phone,
  isPrimary: r.isPrimary,
  notes: r.notes,
  createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
);

DocumentsCompanion documentCompanion(Document d, {required int updatedAt}) {
  String? link(DocumentOwnerKind k) => d.owner.kind == k ? d.owner.id : null;
  return DocumentsCompanion(
    id: Value(d.id),
    diverId: Value(d.diverId),
    diveId: Value(link(DocumentOwnerKind.dive)),
    siteId: Value(link(DocumentOwnerKind.site)),
    tripId: Value(link(DocumentOwnerKind.trip)),
    equipmentId: Value(link(DocumentOwnerKind.equipment)),
    courseId: Value(link(DocumentOwnerKind.course)),
    certificationId: Value(link(DocumentOwnerKind.certification)),
    buddyId: Value(link(DocumentOwnerKind.buddy)),
    diveCenterId: Value(link(DocumentOwnerKind.diveCenter)),
    type: Value(d.type.storage),
    title: Value(d.title),
    issuer: Value(d.issuer),
    referenceNumber: Value(d.referenceNumber),
    issueDate: Value(d.issueDate?.millisecondsSinceEpoch),
    expiryDate: Value(d.expiryDate?.millisecondsSinceEpoch),
    reminderLeadDays: Value(d.reminderLeadDays),
    emergencyPhone: Value(
      d.type == DocumentType.insurance ? d.emergencyPhone : null,
    ),
    phone: Value(d.type == DocumentType.insurance ? d.phone : null),
    isPrimary: Value(d.type == DocumentType.insurance && d.isPrimary),
    notes: Value(d.notes),
    createdAt: Value(d.createdAt.millisecondsSinceEpoch),
    updatedAt: Value(updatedAt),
  );
}

DocumentPage pageFromRow(DocumentPageRow r) => DocumentPage(
  id: r.id,
  documentId: r.documentId,
  pageIndex: r.pageIndex,
  side: DocumentPageSide.fromStorage(r.side),
  fileName: r.fileName,
  mimeType: r.mimeType,
  sizeBytes: r.sizeBytes,
  bytes: r.bytes,
  createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
);
```

- [ ] **Step 4: Write the repository**

Follow `CertificationRepository` for logging, `SyncRepository`, `SyncEventBus` and the `_uuid` field. Key methods:

```dart
// lib/features/documents/data/repositories/document_repository.dart
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/documents/data/repositories/document_row_mapper.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

class DocumentListEntry {
  final Document document;
  final String? ownerLabel;
  final int pageCount;
  const DocumentListEntry(this.document, this.ownerLabel, this.pageCount);
}

typedef CardImages = ({Uint8List? front, Uint8List? back});

class DocumentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DocumentRepository);

  static const _docEntity = 'documents';
  static const _pageEntity = 'documentPages';

  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.documents),
      TableUpdateQuery.onTable(_db.documentPages),
    ]),
  );

  Future<Document?> getById(String id) async {
    final row = await (_db.select(
      _db.documents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : documentFromRow(row);
  }

  Future<List<Document>> getForOwner(
    DocumentOwner owner, {
    String? diverId,
  }) async {
    final q = _db.select(_db.documents);
    if (owner.isPersonal) {
      q.where(
        (t) =>
            t.diveId.isNull() &
            t.siteId.isNull() &
            t.tripId.isNull() &
            t.equipmentId.isNull() &
            t.courseId.isNull() &
            t.certificationId.isNull() &
            t.buddyId.isNull() &
            t.diveCenterId.isNull(),
      );
    } else {
      // Drift has no dynamic column lookup on the typed table; use SQL.
      final column = kDocumentOwnerColumns[owner.kind]!;
      final rows = await _db
          .customSelect(
            'SELECT * FROM documents WHERE $column = ? '
            '${diverId == null ? '' : 'AND diver_id = ? '}'
            'ORDER BY type, title, created_at',
            variables: [
              Variable.withString(owner.id!),
              if (diverId != null) Variable.withString(diverId),
            ],
            readsFrom: {_db.documents},
          )
          .map((r) => _db.documents.map(r.data))
          .get();
      return rows.map(documentFromRow).toList();
    }
    if (diverId != null) q.where((t) => t.diverId.equals(diverId));
    q.orderBy([(t) => OrderingTerm(expression: t.type)]);
    return (await q.get()).map(documentFromRow).toList();
  }
```

The owner branch returns from the `customSelect`; the personal branch falls through to the typed query. Continue:

```dart
  /// Every document of [diverId], with a display label for its owner.
  Future<List<DocumentListEntry>> getAllForDiver(String diverId) async {
    final rows = await _db
        .customSelect(
          'SELECT d.*, '
          '(SELECT COUNT(*) FROM document_pages p WHERE p.document_id = d.id) '
          '  AS page_count, '
          'COALESCE(s.name, t.name, e.name, c.name, cert.name, b.name, '
          '  dc.name, dv.name, '
          "  CASE WHEN dv.dive_number IS NOT NULL THEN '#' || dv.dive_number "
          '  END) AS owner_label '
          'FROM documents d '
          'LEFT JOIN dive_sites s ON s.id = d.site_id '
          'LEFT JOIN trips t ON t.id = d.trip_id '
          'LEFT JOIN equipment e ON e.id = d.equipment_id '
          'LEFT JOIN courses c ON c.id = d.course_id '
          'LEFT JOIN certifications cert ON cert.id = d.certification_id '
          'LEFT JOIN buddies b ON b.id = d.buddy_id '
          'LEFT JOIN dive_centers dc ON dc.id = d.dive_center_id '
          'LEFT JOIN dives dv ON dv.id = d.dive_id '
          'WHERE d.diver_id = ? '
          'ORDER BY d.type, d.title, d.created_at',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.documents, _db.documentPages},
        )
        .get();
    return [
      for (final r in rows)
        DocumentListEntry(
          documentFromRow(_db.documents.map(r.data)),
          r.readNullable<String>('owner_label'),
          r.read<int>('page_count'),
        ),
    ];
  }

  Future<List<DocumentPage>> getPages(
    String documentId, {
    bool withBytes = true,
  }) async {
    final rows =
        await (_db.select(_db.documentPages)
              ..where((t) => t.documentId.equals(documentId))
              ..orderBy([(t) => OrderingTerm(expression: t.pageIndex)]))
            .get();
    return [
      for (final r in rows)
        withBytes ? pageFromRow(r) : pageFromRow(r).copyWithoutBytes(),
    ];
  }

  Future<DocumentPage?> getFirstPage(String documentId) async {
    final row =
        await (_db.select(_db.documentPages)
              ..where((t) => t.documentId.equals(documentId))
              ..orderBy([(t) => OrderingTerm(expression: t.pageIndex)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : pageFromRow(row);
  }
```

Add `DocumentPage copyWithoutBytes()` to the entity in Task 1's file (returns the same page with `bytes: null`; write it as a named constructor-style method since `copyWith(bytes: null)` keeps bytes). Then the write path:

```dart
  /// Saves [document] and makes [pages] its exact page list: new pages
  /// (empty id) are inserted, kept pages updated when changed, missing ones
  /// deleted and tombstoned. One transaction.
  Future<Document> save(Document document, List<DocumentPage> pages) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final id = document.id.isEmpty ? _uuid.v4() : document.id;
    final doc = document.copyWith(
      id: id,
      createdAt: document.id.isEmpty ? now : document.createdAt,
      updatedAt: now,
    );
    try {
      await _db.transaction(() async {
        if (doc.type == DocumentType.insurance && doc.isPrimary) {
          await _clearOtherPrimaries(doc.diverId, id, nowMs);
        }
        await _db
            .into(_db.documents)
            .insertOnConflictUpdate(documentCompanion(doc, updatedAt: nowMs));
        await _syncRepository.markRecordPending(
          entityType: _docEntity,
          recordId: id,
          localUpdatedAt: nowMs,
        );
        await _replacePages(id, pages, nowMs);
      });
      SyncEventBus.notifyLocalChange();
      return doc;
    } catch (e, st) {
      _log.error('Failed to save document $id', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _clearOtherPrimaries(String diverId, String keepId, int now) async {
    final others =
        await (_db.select(_db.documents)..where(
              (t) =>
                  t.diverId.equals(diverId) &
                  t.type.equals(DocumentType.insurance.storage) &
                  t.isPrimary.equals(true) &
                  t.id.equals(keepId).not(),
            ))
            .get();
    for (final o in others) {
      await (_db.update(_db.documents)..where((t) => t.id.equals(o.id))).write(
        DocumentsCompanion(isPrimary: const Value(false), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: _docEntity,
        recordId: o.id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _replacePages(
    String documentId,
    List<DocumentPage> pages,
    int now,
  ) async {
    final existing = {
      for (final p in await getPages(documentId)) p.id: p,
    };
    final keptIds = <String>{};
    for (final (index, page) in pages.indexed) {
      final pageId = page.id.isEmpty ? _uuid.v4() : page.id;
      keptIds.add(pageId);
      final old = existing[pageId];
      final bytes = page.bytes ?? old?.bytes;
      if (bytes == null) {
        throw ArgumentError('page $pageId has no bytes');
      }
      final unchanged =
          old != null &&
          old.pageIndex == index &&
          old.side == page.side &&
          const ListEquality<int>().equals(old.bytes, bytes);
      if (unchanged) continue;
      await _db
          .into(_db.documentPages)
          .insertOnConflictUpdate(
            DocumentPagesCompanion(
              id: Value(pageId),
              documentId: Value(documentId),
              pageIndex: Value(index),
              side: Value(page.side?.name),
              fileName: Value(page.fileName),
              mimeType: Value(page.mimeType),
              sizeBytes: Value(bytes.length),
              bytes: Value(bytes),
              createdAt: Value(old?.createdAt.millisecondsSinceEpoch ?? now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: _pageEntity,
        recordId: pageId,
        localUpdatedAt: now,
      );
    }
    for (final goneId in existing.keys.where((id) => !keptIds.contains(id))) {
      await (_db.delete(
        _db.documentPages,
      )..where((t) => t.id.equals(goneId))).go();
      await _syncRepository.logDeletion(
        entityType: _pageEntity,
        recordId: goneId,
      );
    }
  }

  Future<void> delete(String id) async {
    await _db.transaction(() => _deleteIds([id]));
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every document an owner holds. Owner delete
  /// paths call this inside their own transaction, before deleting the
  /// owner: the schema's SET NULL would otherwise turn the documents into
  /// personal ones, and no cascade writes a tombstone.
  Future<void> deleteForOwner(DocumentOwnerKind kind, String ownerId) =>
      deleteForOwners(kind, [ownerId]);

  Future<void> deleteForOwners(
    DocumentOwnerKind kind,
    List<String> ownerIds,
  ) async {
    if (ownerIds.isEmpty) return;
    final column = kDocumentOwnerColumns[kind];
    if (column == null) {
      throw ArgumentError('deleteForOwners needs an owner kind, not $kind');
    }
    final placeholders = List.filled(ownerIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT id FROM documents WHERE $column IN ($placeholders)',
          variables: [for (final o in ownerIds) Variable.withString(o)],
        )
        .get();
    await _deleteIds([for (final r in rows) r.read<String>('id')]);
  }

  Future<void> _deleteIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final pageIds =
        await (_db.selectOnly(_db.documentPages)
              ..addColumns([_db.documentPages.id])
              ..where(_db.documentPages.documentId.isIn(ids)))
            .map((r) => r.read(_db.documentPages.id)!)
            .get();
    await (_db.delete(
      _db.documentPages,
    )..where((t) => t.documentId.isIn(ids))).go();
    await (_db.delete(_db.documents)..where((t) => t.id.isIn(ids))).go();
    await _syncRepository.logDeletions(
      entityType: _pageEntity,
      recordIds: pageIds,
    );
    await _syncRepository.logDeletions(entityType: _docEntity, recordIds: ids);
  }
```

Queries for the read models:

```dart
  /// Each diver's primary insurance. Two primaries (a sync merge of two
  /// devices' edits) resolve to the most recently updated, then by id.
  Future<Map<String, Document>> primaryInsuranceByDiver({
    String? diverId,
  }) async {
    final q = _db.select(_db.documents)
      ..where(
        (t) =>
            t.type.equals(DocumentType.insurance.storage) &
            t.isPrimary.equals(true),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (diverId != null) q.where((t) => t.diverId.equals(diverId));
    final out = <String, Document>{};
    for (final row in await q.get()) {
      out.putIfAbsent(row.diverId, () => documentFromRow(row));
    }
    return out;
  }

  /// Latest medical clearance expiry per diver.
  Future<Map<String, DateTime>> latestClearanceExpiryByDiver({
    String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT diver_id, MAX(expiry_date) AS e FROM documents '
          "WHERE type = 'medicalClearance' AND expiry_date IS NOT NULL "
          '${diverId == null ? '' : 'AND diver_id = ? '}'
          'GROUP BY diver_id',
          variables: [if (diverId != null) Variable.withString(diverId)],
          readsFrom: {_db.documents},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('diver_id'): DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('e'),
        ),
    };
  }

  Future<Map<String, CardImages>> cardImagesFor(
    List<String> certificationIds,
  ) async {
    if (certificationIds.isEmpty) return const {};
    final docIds = {
      for (final c in certificationIds) documentCertificationCardId(c): c,
    };
    final pages =
        await (_db.select(_db.documentPages)
              ..where((t) => t.documentId.isIn(docIds.keys)))
            .get();
    final out = <String, CardImages>{};
    for (final p in pages) {
      final certId = docIds[p.documentId]!;
      final current = out[certId] ?? (front: null, back: null);
      out[certId] = switch (DocumentPageSide.fromStorage(p.side)) {
        DocumentPageSide.front => (front: p.bytes, back: current.back),
        DocumentPageSide.back => (front: current.front, back: p.bytes),
        null => current,
      };
    }
    return out;
  }

  /// Writes a certification's card images. Null clears that side; both
  /// null deletes the card document. Unchanged bytes write nothing, so a
  /// rename of the certification does not re-stamp its pages.
  Future<void> saveCardImages({
    required String certificationId,
    required String diverId,
    required Uint8List? front,
    required Uint8List? back,
  }) async {
    final docId = documentCertificationCardId(certificationId);
    final existing = await getById(docId);
    if (front == null && back == null) {
      if (existing != null) await _db.transaction(() => _deleteIds([docId]));
      return;
    }
    final current = (await cardImagesFor([certificationId]))[certificationId];
    const eq = ListEquality<int>();
    if (existing != null &&
        current != null &&
        eq.equals(current.front, front) &&
        eq.equals(current.back, back)) {
      return;
    }
    final now = DateTime.now();
    final doc =
        existing ??
        Document(
          id: docId,
          diverId: diverId,
          owner: DocumentOwner(DocumentOwnerKind.certification, certificationId),
          type: DocumentType.certificationCard,
          createdAt: now,
          updatedAt: now,
        );
    DocumentPage side(DocumentPageSide s, Uint8List bytes) => DocumentPage(
      id: documentCardPageId(docId, s),
      documentId: docId,
      pageIndex: 0,
      side: s,
      fileName: '${s.name}.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      bytes: bytes,
      createdAt: now,
      updatedAt: now,
    );
    await save(doc, [
      if (front != null) side(DocumentPageSide.front, front),
      if (back != null) side(DocumentPageSide.back, back),
    ]);
  }

  Future<List<Document>> getRemindingForDiver(String diverId) async {
    final rows =
        await (_db.select(_db.documents)..where(
              (t) =>
                  t.diverId.equals(diverId) &
                  t.expiryDate.isNotNull() &
                  t.type.equals(DocumentType.certificationCard.storage).not(),
            ))
            .get();
    return rows.map(documentFromRow).toList();
  }
}
```

The deterministic page ids in `saveCardImages` are new rows on first save (`existing` page map lacks them), so `_replacePages` inserts them; on later saves they match and the unchanged check skips them.

- [ ] **Step 5: Run the tests, expect PASS; analyze**

Run: `flutter test test/features/documents/data/ && flutter analyze lib/features/documents`

- [ ] **Step 6: Commit**

```bash
git add lib/features/documents/data lib/features/documents/domain test/features/documents/data
git commit -m "feat(documents): document repository"
```

---

### Task 4: Sync registration and changeset size guard

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every site listed below)
- Modify: `lib/core/services/sync/sync_service.dart` (apply order ~1667/1746, `entityHasUpdatedAt` ~2582, `parentRefs` ~2767)
- Modify: `lib/core/data/repositories/sync_repository.dart:45` (`hlcTargets`)
- Modify: `lib/core/services/sync/conflict_reference.dart` (~100), `lib/features/settings/presentation/widgets/conflict_reference_labels.dart` (~94)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` map)
- Test: `test/core/services/sync/documents_sync_test.dart`

**Interfaces:**
- Consumes: Task 2 tables, Task 3 repository.
- Produces: entity keys `'documents'` and `'documentPages'`; `SyncData.documents`, `SyncData.documentPages`.

- [ ] **Step 1: Write the failing round-trip test**

```dart
// test/core/services/sync/documents_sync_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('a document and its page export, re-import and keep bytes', () async {
    final repo = DocumentRepository();
    final doc = await repo.save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        issuer: 'DAN',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    final serializer = SyncDataSerializer();
    final pageRecord = (await serializer.fetchRecords(
      'documentPages',
      [(await repo.getPages(doc.id)).single.id],
    )).single;
    final docRecord = await serializer.fetchRecord('documents', doc.id);
    expect(docRecord, isNotNull);
    expect(pageRecord['bytes'], isA<String>()); // base64 on the wire

    await repo.delete(doc.id);
    await serializer.upsertRecord('documents', docRecord!);
    await serializer.upsertRecord('documentPages', pageRecord);
    final back = await repo.getPages(doc.id);
    expect(back.single.bytes, [1, 2, 3]);
  });

  test('pending page bytes count toward the oversized-delta guard', () async {
    final serializer = SyncDataSerializer();
    final before = await serializer.pendingSeriesBlobBytes(null);
    final repo = DocumentRepository();
    await repo.save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.other,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'a.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1000,
          bytes: Uint8List(1000),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    expect(await serializer.pendingSeriesBlobBytes(null), before + 1000);
  });
}
```

Match the real method names and signatures of `fetchRecord`, `fetchRecords`, `upsertRecord` and `pendingSeriesBlobBytes` (serializer lines ~2796, ~3388, ~4458, ~8803) and how other sync tests construct the serializer (`grep -rn "SyncDataSerializer(" test/core/services/sync | head -3`).

- [ ] **Step 2: Run, expect FAIL** (unknown entity)

Run: `flutter test test/core/services/sync/documents_sync_test.dart`

- [ ] **Step 3: Register `documents` like `certifications` and `documentPages` like `diveProfileSeries`**

In `sync_data_serializer.dart`, at each site, add a `documents` entry next to `certifications` and a `documentPages` entry next to it:

1. `SyncData` fields (~283): `final List<Map<String, dynamic>> documents;` and `documentPages`.
2. Constructor defaults (~403): `this.documents = const [], this.documentPages = const [],`.
3. `toJson` (~518): `'documents': documents, 'documentPages': documentPages,` in the same relative position as in `_baseTables`.
4. `fromJson` (~634): `documents: _parseList(json['documents']), documentPages: _parseList(json['documentPages']),`.
5. `_baseTables` (~990): after certifications:

```dart
    (key: 'documents', table: _db.documents, blob: false, full: null),
    (key: 'documentPages', table: _db.documentPages, blob: true, full: null),
```

6. `_buildSyncData` (~2183):

```dart
      documents: await _safeExport(
        'documents',
        () => _exportDocuments(hlcSince),
      ),
      documentPages: await _safeExport(
        'documentPages',
        () => _exportDocumentPages(hlcSince),
      ),
```

7. Exporters (next to `_exportCertifications` ~8443):

```dart
  Future<List<Map<String, dynamic>>> _exportDocuments(String? hlcSince) async {
    final query = _db.select(_db.documents);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    return (await query.get()).map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDocumentPages(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.documentPages);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson(serializer: _syncBlobSerializer)).toList();
  }
```

8. `fetchRecord` switch (~2929): mirror `certifications`, using `_syncBlobSerializer` for `documentPages`.
9. `fetchRecords` switch (~3778): add a `documentPages` case mirroring the BLOB case there; `documents` mirrors a plain table.
10. `upsertRecord` (~4636) and `upsertRecords` (~5632):

```dart
      case 'documents':
        await _db.into(_db.documents).insertOnConflictUpdate(
          DocumentRow.fromJson(data).toCompanion(false),
        );
      case 'documentPages':
        await _db.into(_db.documentPages).insertOnConflictUpdate(
          DocumentPageRow.fromJson(
            data,
            serializer: _syncBlobSerializer,
          ).toCompanion(false),
        );
```

11. `recordIdsFor` (~6994): `case 'documents': return plain(_db.documents, _db.documents.id);` and the same for `documentPages`.
12. `_syncTableFor` (~7443): `case 'documents': return _db.documents; case 'documentPages': return _db.documentPages;`.
13. `deleteRecord` (~7627): mirror `certifications` for both.
14. `pendingSeriesBlobBytes` (~8803): add `'document_pages': 'bytes',` to `blobColumnByTable`, with a comment: a 10 MB scan burst must trip the streamed-base fallback, not build one giant in-memory delta.

In `sync_service.dart`:

- Apply order (~1746), parent before child, after certifications:

```dart
        (type: 'documents', records: data.documents, hasUpdatedAt: true),
        (
          type: 'documentPages',
          records: data.documentPages,
          hasUpdatedAt: true,
        ),
```

- `entityHasUpdatedAt` (~2582): `'documents': true, 'documentPages': true,`.
- `parentRefs` (~2767), using the entity keys already used for these parents there (check with `grep -n "parent: '" lib/core/services/sync/sync_service.dart | sort -u -t"'" -k4 | head -40`):

```dart
    'documents': [
      (field: 'diverId', parent: 'divers', nullable: false),
      (field: 'diveId', parent: 'dives', nullable: true),
      (field: 'siteId', parent: 'diveSites', nullable: true),
      (field: 'tripId', parent: 'trips', nullable: true),
      (field: 'equipmentId', parent: 'equipment', nullable: true),
      (field: 'courseId', parent: 'courses', nullable: true),
      (field: 'certificationId', parent: 'certifications', nullable: true),
      (field: 'buddyId', parent: 'buddies', nullable: true),
      (field: 'diveCenterId', parent: 'diveCenters', nullable: true),
    ],
    'documentPages': [
      (field: 'documentId', parent: 'documents', nullable: false),
    ],
```

In `sync_repository.dart` `hlcTargets`:

```dart
    'documents': (table: 'documents', pk: 'id'),
    'documentPages': (table: 'document_pages', pk: 'id'),
```

In `conflict_reference.dart` add `'documentId': 'documents',`, and in `conflict_reference_labels.dart` a `case 'documents': return l10n.settings_conflict_ref_document;` (ARB key in Task 5).

In `test/core/services/sync/sync_parent_refs_completeness_test.dart` add `'documents': 'documents', 'document_pages': 'documentPages',` to `syncedTables`.

- [ ] **Step 4: Run the sync suite and the guard tests**

Run: `flutter test test/core/services/sync/`
Expected: PASS, including `sync_hlc_target_registration_test`, `sync_base_streaming_parity_test`, `base_publish_streaming_parity_test`, `sync_data_serializer_record_ids_test`, `sync_parent_refs_completeness_test`. Also extend the hand-kept lists in `sync_serializer_fetch_record_test.dart:85,225`, `sync_serializer_upsert_test.dart:109` and `sync_data_serializer_batch_coverage_test.dart:94` with the two entities.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync lib/core/data/repositories/sync_repository.dart lib/features/settings/presentation/widgets/conflict_reference_labels.dart test/core/services/sync
git commit -m "feat(documents): sync documents and document pages"
```

---

### Task 5: Conflict catalogue and l10n foundation

**Files:**
- Create: `lib/features/settings/presentation/conflicts/catalogue/document_fields.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart` (import and add to both `_merge` lists)
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: existing `conflict_field_catalogue_coverage_test.dart`, `conflict_labels_complete_test.dart`, `test/l10n/`

**Interfaces:**
- Produces: `const Map<String, ConflictField> documentFields`, `documentOverrides`; ARB keys used by later tasks (table below).

- [ ] **Step 1: Run the coverage test, expect FAIL** listing the new columns

Run: `flutter test test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart`

- [ ] **Step 2: Write the catalogue**

```dart
// lib/features/settings/presentation/conflicts/catalogue/document_fields.dart
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';

/// Conflict-card fields for documents and document pages (issue #2613).
/// Keys already catalogued elsewhere (issuer, notes, title, phone ...)
/// are reused from there; only new column names appear here.
final Map<String, ConflictField> documentFields = {
  'referenceNumber': ConflictField(
    (l) => l.settings_conflict_field_referenceNumber,
    FieldKind.shortText,
  ),
  'reminderLeadDays': ConflictField(
    (l) => l.settings_conflict_field_reminderLeadDays,
    FieldKind.number,
  ),
  'emergencyPhone': ConflictField(
    (l) => l.settings_conflict_field_emergencyPhone,
    FieldKind.shortText,
  ),
  'isPrimary': ConflictField(
    (l) => l.settings_conflict_field_isPrimary,
    FieldKind.boolean,
  ),
  'pageIndex': ConflictField(
    (l) => l.settings_conflict_field_pageIndex,
    FieldKind.number,
  ),
  'side': ConflictField((l) => l.settings_conflict_field_side, FieldKind.shortText),
  'fileName': ConflictField(
    (l) => l.settings_conflict_field_fileName,
    FieldKind.shortText,
  ),
  'mimeType': ConflictField(
    (l) => l.settings_conflict_field_mimeType,
    FieldKind.shortText,
  ),
  'sizeBytes': ConflictField(
    (l) => l.settings_conflict_field_sizeBytes,
    FieldKind.number,
  ),
  'bytes': ConflictField(
    (l) => l.settings_conflict_field_pageContent,
    FieldKind.opaque,
  ),
};

final Map<String, ConflictField> documentOverrides = {};
```

Run the coverage test first and add entries only for the keys it reports as missing; drop any of the above it reports as duplicates (a key in two files asserts). Match the real `FieldKind` values and the `ConflictField` import path used in `people_planning_fields.dart`. Register both maps in `conflict_field_catalogue.dart`.

- [ ] **Step 3: Add the ARB keys used across the feature**

Add to `app_en.arb` (with `@` metadata for placeholders) and to the 10 other locales with real translations. Keys:

| Key | English |
| --- | --- |
| `nav_documents` | Documents |
| `documents_title` | Documents |
| `documents_type_insurance` | Insurance |
| `documents_type_medicalClearance` | Medical clearance |
| `documents_type_certificationCard` | Certification card |
| `documents_type_permit` | Permit |
| `documents_type_booking` | Booking |
| `documents_type_receipt` | Receipt |
| `documents_type_manual` | Manual |
| `documents_type_map` | Map |
| `documents_type_other` | Document |
| `documents_owner_personal` | Personal |
| `documents_owner_dive` | Dives |
| `documents_owner_site` | Sites |
| `documents_owner_trip` | Trips |
| `documents_owner_equipment` | Equipment |
| `documents_owner_course` | Courses |
| `documents_owner_certification` | Certifications |
| `documents_owner_buddy` | Buddies |
| `documents_owner_diveCenter` | Dive centers |
| `documents_expiring_title` | Needs attention |
| `documents_badge_expired` | Expired |
| `documents_badge_expiresInDays` | `{count, plural, =0{Expires today} =1{Expires tomorrow} other{Expires in {count} days}}` |
| `documents_empty` | No documents yet |
| `documents_search_hint` | Search documents |
| `documents_add` | Add document |
| `documents_section_title` | Documents |
| `documents_section_empty` | No documents attached |
| `documents_edit_newTitle` | New document |
| `documents_edit_editTitle` | Edit document |
| `documents_field_type` | Type |
| `documents_field_title` | Title |
| `documents_field_issuer` | Issued by |
| `documents_field_issuerInsurance` | Insurer |
| `documents_field_referenceNumber` | Number |
| `documents_field_referenceNumberInsurance` | Policy number |
| `documents_field_issueDate` | Issued |
| `documents_field_expiryDate` | Expires |
| `documents_field_reminderLead` | Remind me |
| `documents_field_reminderLeadDays` | `{count, plural, =0{Off} =1{1 day before} other{{count} days before}}` |
| `documents_field_emergencyPhone` | 24-hour emergency line |
| `documents_field_phone` | Office phone |
| `documents_field_isPrimary` | Primary insurance |
| `documents_field_isPrimary_subtitle` | Shown on the emergency card and the home screen |
| `documents_field_notes` | Notes |
| `documents_pages_title` | Pages |
| `documents_pages_front` | Front |
| `documents_pages_back` | Back |
| `documents_pages_addCamera` | Take photo |
| `documents_pages_addGallery` | Choose photo |
| `documents_pages_addFile` | Choose file |
| `documents_pages_remove` | Remove page |
| `documents_pages_tooLarge` | `This file is {size}. The limit is 10 MB.` (placeholder `size` String) |
| `documents_pages_unsupported` | `{extension} files are not supported. Use a photo, PDF, Word or text file.` |
| `documents_page_cannotDisplay` | Can't display this page |
| `documents_page_openWith` | Open with... |
| `documents_page_counter` | `{current} of {total}` (int placeholders) |
| `documents_delete_title` | Delete document? |
| `documents_delete_content` | This deletes the document and all its pages on every synced device. |
| `documents_deleted` | Document deleted |
| `documents_saved` | Document saved |
| `documents_error_save` | `Couldn't save the document: {error}` |
| `documents_filter_all` | All |
| `documents_detail_owner` | Filed under |
| `documents_profileHub_documents` | Documents |
| `documents_profileHub_documents_count` | `{count, plural, =0{None yet} =1{1 document} other{{count} documents}}` |
| `documents_medical_clearances` | Medical clearances |
| `documents_medical_addClearance` | Add clearance |
| `dashboard_gauges_documentExpires` | `{title} expires {date}` |
| `dashboard_gauges_documentExpired` | `{title} expired` |
| `dashboard_gauges_documentsNeedAttention` | `{count, plural, =1{1 document needs attention} other{{count} documents need attention}}` |
| `settings_homeChips_documents` | Documents |
| `notifications_document_expiresSoon_title` | `{title} expires soon` |
| `notifications_document_expiresSoon_body` | `{count, plural, =1{Expires tomorrow.} other{Expires in {count} days.}}` |
| `notifications_document_expiresToday_title` | `{title} expires today` |
| `notifications_document_expiresToday_body` | Renew it before your next dive. |
| `settings_conflict_ref_document` | Document |
| `settings_conflict_field_referenceNumber` | Number |
| `settings_conflict_field_reminderLeadDays` | Reminder |
| `settings_conflict_field_emergencyPhone` | Emergency line |
| `settings_conflict_field_isPrimary` | Primary |
| `settings_conflict_field_pageIndex` | Page order |
| `settings_conflict_field_side` | Card side |
| `settings_conflict_field_fileName` | File name |
| `settings_conflict_field_mimeType` | File type |
| `settings_conflict_field_sizeBytes` | File size |
| `settings_conflict_field_pageContent` | Page content |

Run `flutter gen-l10n` afterwards. Keep only the conflict keys Step 2 actually uses.

- [ ] **Step 4: Run catalogue and l10n tests, expect PASS**

Run: `flutter gen-l10n && flutter test test/features/settings/presentation/conflicts/ test/l10n/`

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/conflicts lib/l10n
git commit -m "feat(documents): conflict catalogue and strings"
```

---

### Task 6: Owner delete paths tombstone their documents

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:2357` (`_deleteDiveRows`) and the bulk path (~2408)
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart:577` (`_deleteSiteRows`)
- Modify: `lib/features/trips/data/repositories/trip_repository.dart:360` (inside the transaction)
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart:581` (inside the transaction) and `deleteOwnedEquipment` (`:683`)
- Modify: `lib/features/courses/data/repositories/course_repository.dart:367`
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart:290`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart:363-379` and `bulkDeleteBuddies` (`:1204`)
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart:236`
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart` (first entries of `diverDiveSteps`, `:79`)
- Test: `test/features/documents/data/owner_delete_documents_test.dart`, `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart` (run)

**Interfaces:**
- Consumes: `DocumentRepository.deleteForOwner(kind, id)` / `deleteForOwners(kind, ids)`.

- [ ] **Step 1: Write the failing test, one case per owner**

```dart
// test/features/documents/data/owner_delete_documents_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../helpers/test_database.dart';

Future<int> docCount(AppDatabase db) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM documents').getSingle())
        .read<int>('n');

Future<void> addDoc(DocumentOwnerKind kind, String ownerId) =>
    DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: DocumentOwner(kind, ownerId),
        type: DocumentType.other,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('deleting a certification deletes its documents', () async {
    await db.customStatement(
      "INSERT INTO certifications (id, diver_id, name, agency, created_at, "
      "updated_at) VALUES ('c1', 'd1', 'OW', 'padi', 0, 0)",
    );
    await addDoc(DocumentOwnerKind.certification, 'c1');
    await CertificationRepository().deleteCertification('c1');
    expect(await docCount(db), 0);
  });

  test('deleting a buddy deletes their certifications documents too',
      () async {
    await db.customStatement(
      "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
      "VALUES ('b1', 'd1', 'Bo', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO certifications (id, buddy_id, name, agency, created_at, "
      "updated_at) VALUES ('c2', 'b1', 'OW', 'padi', 0, 0)",
    );
    await addDoc(DocumentOwnerKind.buddy, 'b1');
    await addDoc(DocumentOwnerKind.certification, 'c2');
    await BuddyRepository().deleteBuddy('b1');
    expect(await docCount(db), 0);
  });

  // Same shape for: dive (DiveRepositoryImpl.deleteDive and bulk), site
  // (deleteSite and bulkDeleteSites), trip (deleteTrip with actingDiverId
  // 'd1'), equipment (deleteEquipment), course (deleteCourse), dive center
  // (deleteDiveCenter), and diver delete (deleteDiverWithReassignment): seed
  // the owner row with its NOT NULL columns, add a document, delete, expect
  // docCount 0 and a 'documents' row in deletion_log.
}
```

Write the remaining eight cases in full when implementing (each seeds its owner with the columns its table requires; read the table class for NOT NULL columns).

- [ ] **Step 2: Run, expect FAIL** (documents survive as personal via SET NULL)

- [ ] **Step 3: Call the cleanup in each delete path, inside its transaction, before the owner row is deleted**

Pattern (certification, which has no transaction today; wrap it):

```dart
  Future<void> deleteCertification(String id, {bool notify = true}) async {
    try {
      _log.info('Deleting certification: $id');
      await _db.transaction(() async {
        // Currency prefs and events cascade with the row, and a cascade
        // writes no tombstones, so log them before they go.
        await CertificationCurrencyRepository().tombstoneChildrenOf(id);
        // Its documents (the card and any others) go with it, tombstoned.
        await DocumentRepository().deleteForOwner(
          DocumentOwnerKind.certification,
          id,
        );
        await (_db.delete(
          _db.certifications,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'certifications',
          recordId: id,
        );
      });
      if (notify) SyncEventBus.notifyLocalChange();
      _log.info('Deleted certification: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete certification: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Buddy (`buddy_repository.dart:363-379`), before the inline cert delete loop:

```dart
        final buddyCertIds = [
          for (final c in await certificationRepo.getCertificationsByBuddy(id))
            c.id,
        ];
        await DocumentRepository().deleteForOwners(
          DocumentOwnerKind.certification,
          buddyCertIds,
        );
        await DocumentRepository().deleteForOwner(DocumentOwnerKind.buddy, id);
```

(Use whatever variable the loop already uses for the buddy's certifications instead of fetching twice.) Same in `bulkDeleteBuddies` with `deleteForOwners`.

Others, one line each inside the existing transaction, before the owner row's DELETE:

- Dive `_deleteDiveRows`: `await DocumentRepository().deleteForOwners(DocumentOwnerKind.dive, ids);`
- Site `_deleteSiteRows`: `DocumentOwnerKind.site`
- Trip: `await DocumentRepository().deleteForOwner(DocumentOwnerKind.trip, id);` after `clearDiveTripLinks`
- Equipment: `DocumentOwnerKind.equipment` (and in `deleteOwnedEquipment`)
- Course: `DocumentOwnerKind.course`
- Dive center: `DocumentOwnerKind.diveCenter`

Diver delete: prepend to `diverDiveSteps` in `diver_delete_steps.dart`:

```dart
  // Documents first: their owner links (dive, site, trip, gear, course,
  // cert, buddy, center) all point at rows deleted below. Documents follow
  // the diver who filed them, including those on a shared site that
  // survives the delete (issue #2613).
  (
    table: 'document_pages',
    entityType: 'documentPages',
    where: 'document_id IN (SELECT id FROM documents WHERE diver_id = ?1)',
  ),
  (table: 'documents', entityType: 'documents', where: 'diver_id = ?1'),
```

- [ ] **Step 4: Run the new test and the owner suites**

Run: `flutter test test/features/documents/data/ test/features/divers/data/repositories/diver_delete_owned_tables_test.dart test/features/certifications test/features/buddies/data test/features/trips/data test/features/courses/data test/features/dive_centers/data test/features/equipment/data test/features/dive_sites/data`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features test/features/documents/data
git commit -m "feat(documents): delete an owner's documents with it"
```

---

### Task 7: Diver insurance and clearance read from documents

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (`watchDiversChanges` `:140`, `getAllDivers` `:108`, `getDefaultDiver` `:144`, `getDiverById` `:172`, `createDiver` `:196`, `updateDiver` `:276`)
- Modify: `lib/features/divers/domain/entities/diver.dart:29` (add `DiverInsurance.fromDocument`)
- Test: `test/features/divers/data/repositories/diver_documents_read_model_test.dart`; run `diver_repository_additional_test.dart`, `uddf_owner_insurance_export_test.dart`, `emergency_card_page_test.dart`, `universal_adapter_multi_diver_test.dart`

**Interfaces:**
- Consumes: `DocumentRepository.primaryInsuranceByDiver`, `latestClearanceExpiryByDiver`, `save`, `documentInsuranceId`.
- Produces: `Diver.insurance` and `Diver.medicalClearanceExpiryDate` hydrated from documents; `DiverInsurance.fromDocument(Document)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/divers/data/repositories/diver_documents_read_model_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Diver diver({DiverInsurance insurance = const DiverInsurance()}) => Diver(
    id: 'd1',
    name: 'Ana',
    insurance: insurance,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('insurance comes from the primary insurance document', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        issuer: 'DAN',
        referenceNumber: 'P-9',
        emergencyPhone: '+1 911',
        isPrimary: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    final d = await divers.getDiverById('d1');
    expect(d!.insurance.providerLabel, 'DAN');
    expect(d.insurance.policyLabel, 'P-9');
    expect(d.insurance.assistanceLine, '+1 911');
    expect((await divers.getAllDivers()).single.insurance.providerLabel, 'DAN');
  });

  test('clearance expiry comes from the latest clearance document', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    for (final y in [2025, 2027]) {
      await DocumentRepository().save(
        Document(
          id: '',
          diverId: 'd1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.medicalClearance,
          expiryDate: DateTime(y),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        const [],
      );
    }
    expect(
      (await divers.getDiverById('d1'))!.medicalClearanceExpiryDate,
      DateTime(2027),
    );
  });

  test('updateDiver writes no insurance columns and no documents', () async {
    final divers = DiverRepository();
    await divers.createDiver(diver());
    await divers.updateDiver(
      diver(insurance: const DiverInsurance(provider: 'Stale')),
    );
    final db = await divers.rawInsuranceProviderForTest('d1');
    expect(db, isNull);
    expect((await divers.getDiverById('d1'))!.insurance.providerLabel, isNull);
  });

  test('createDiver with insurance files a primary insurance document',
      () async {
    await DiverRepository().createDiver(
      diver(insurance: const DiverInsurance(provider: 'DAN', policyNumber: '7')),
    );
    final doc = await DocumentRepository().getById(documentInsuranceId('d1'));
    expect(doc!.isPrimary, isTrue);
    expect(doc.referenceNumber, '7');
  });
}
```

Replace `rawInsuranceProviderForTest` with a direct query in the test (`db.customSelect('SELECT insurance_provider ...')`) rather than adding a test-only method.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Add `DiverInsurance.fromDocument`**

```dart
  /// The read model of a primary insurance document (issue #2613). The
  /// insurer is the document's issuer, falling back to its title.
  factory DiverInsurance.fromDocument(Document document) => DiverInsurance(
    provider: _presentOrNull(document.issuer) ?? _presentOrNull(document.title),
    policyNumber: document.referenceNumber,
    expiryDate: document.expiryDate,
    emergencyPhone: document.emergencyPhone,
    phone: document.phone,
  );
```

- [ ] **Step 4: Hydrate in the repository**

```dart
  Stream<void> watchDiversChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.divers),
      // Insurance and clearance are read from documents (issue #2613).
      TableUpdateQuery.onTable(_db.documents),
    ]),
  );

  /// Overlays each diver's insurance and clearance from documents. The
  /// diver row's own insurance and clearance columns are never read.
  Future<List<domain.Diver>> _withDocuments(
    List<domain.Diver> divers, {
    String? diverId,
  }) async {
    if (divers.isEmpty) return divers;
    final documents = DocumentRepository();
    final insurance = await documents.primaryInsuranceByDiver(
      diverId: diverId,
    );
    final clearance = await documents.latestClearanceExpiryByDiver(
      diverId: diverId,
    );
    return [
      for (final d in divers)
        d.copyWith(
          insurance: insurance[d.id] == null
              ? const domain.DiverInsurance()
              : domain.DiverInsurance.fromDocument(insurance[d.id]!),
          medicalClearanceExpiryDate: clearance[d.id],
        ),
    ];
  }
```

Wrap the return of `getAllDivers`, `getDefaultDiver` and `getDiverById` through `_withDocuments` (single-diver calls pass `diverId:`). Note `copyWith(insurance: const DiverInsurance())` must actually replace: `insurance ?? this.insurance` keeps a non-null argument, so it works.

In `_mapRowToDiver` set `insurance: const domain.DiverInsurance()` and `medicalClearanceExpiryDate: null` with a comment that `_withDocuments` fills them; delete the `row.insurance*` / `row.medicalClearanceExpiryDate` reads.

In `createDiver` and `updateDiver`, remove the five `insurance*` and the `medicalClearanceExpiryDate` companion values. At the end of `createDiver`, after the insert and inside the transaction:

```dart
        // Imports (the universal adapter's DAN number) hand a new diver an
        // insurance; it is filed as the primary insurance document.
        if (diver.insurance.hasAnyDetail) {
          await DocumentRepository().save(
            Document(
              id: documentInsuranceId(id),
              diverId: id,
              owner: const DocumentOwner.personal(),
              type: DocumentType.insurance,
              issuer: diver.insurance.providerLabel,
              referenceNumber: diver.insurance.policyLabel,
              expiryDate: diver.insurance.expiryDate,
              emergencyPhone: diver.insurance.assistanceLine,
              phone: diver.insurance.officeLine,
              isPrimary: true,
              createdAt: now,
              updatedAt: now,
            ),
            const [],
          );
        }
```

`DocumentRepository.save` opens its own transaction; inside Drift's outer transaction it nests as a savepoint.

- [ ] **Step 5: Run the read-model test and the existing consumers**

Run: `flutter test test/features/divers/ test/core/services/export/uddf/uddf_owner_insurance_export_test.dart test/features/safety/presentation/pages/emergency_card_page_test.dart test/features/dashboard/ test/features/import_wizard/data/adapters/universal_adapter_multi_diver_test.dart`
Expected: PASS. Tests that seeded insurance by writing diver columns or by `updateDiver(copyWith(insurance: ...))` must now seed a document; update those fixtures (`diver_repository_additional_test.dart` insurance cases, any dashboard provider test that reads a real repository).

- [ ] **Step 6: Commit**

```bash
git add lib/features/divers test/features/divers test/core/services/export test/features/safety test/features/dashboard test/features/import_wizard
git commit -m "feat(documents): read diver insurance and clearance from documents"
```

---

### Task 8: Certification card images read and write the card document

**Files:**
- Modify: `lib/features/certifications/data/repositories/certification_repository.dart` (`:23` watch, `createCertification` `:177`, `updateCertification` `:242`, list/get mappers `:399-427`)
- Test: `test/features/certifications/data/repositories/certification_card_document_test.dart`; run the existing certification suites and `test/core/services/pdf_templates/pdf_detailed_language_fields_test.dart`

**Interfaces:**
- Consumes: `DocumentRepository.cardImagesFor`, `saveCardImages`.
- Produces: `Certification.photoFront/photoBack` hydrated from the card document on every read; writes go to the card document.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/certifications/data/repositories/certification_card_document_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Certification cert({Uint8List? front, Uint8List? back}) => Certification(
    id: 'c1',
    diverId: 'd1',
    name: 'Open Water',
    agency: 'padi',
    photoFront: front,
    photoBack: back,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('photos are stored in the card document, not on the row', () async {
    final repo = CertificationRepository();
    await repo.createCertification(
      cert(front: Uint8List.fromList([1]), back: Uint8List.fromList([2])),
    );
    final row = await db
        .customSelect("SELECT photo_front FROM certifications WHERE id = 'c1'")
        .getSingle();
    expect(row.readNullable<Uint8List>('photo_front'), isNull);
    final images = await DocumentRepository().cardImagesFor(['c1']);
    expect(images['c1']!.front, [1]);
    final read = await repo.getCertificationById('c1');
    expect(read!.photoFront, [1]);
    expect(read.photoBack, [2]);
    expect((await repo.getAllCertifications()).single.photoBack, [2]);
  });

  test('a rename leaves the card pages untouched', () async {
    final repo = CertificationRepository();
    await repo.createCertification(cert(front: Uint8List.fromList([1])));
    await db.customStatement('DELETE FROM sync_records');
    final current = (await repo.getCertificationById('c1'))!;
    await repo.updateCertification(current.copyWith(name: 'OW Diver'));
    final pending = await db
        .customSelect(
          "SELECT entity_type FROM sync_records WHERE entity_type LIKE 'document%'",
        )
        .get();
    expect(pending, isEmpty);
  });

  test('a cert without photos creates no card document', () async {
    await CertificationRepository().createCertification(cert());
    expect(
      await DocumentRepository().getById(documentCertificationCardId('c1')),
      isNull,
    );
  });

  test('clearing both photos deletes the card document', () async {
    final repo = CertificationRepository();
    await repo.createCertification(cert(front: Uint8List.fromList([1])));
    final current = (await repo.getCertificationById('c1'))!;
    await repo.updateCertification(current.clearPhotos(clearFront: true));
    expect(
      await DocumentRepository().getById(documentCertificationCardId('c1')),
      isNull,
    );
  });
}
```

Use the real getter names (`getCertificationById`, `getAllCertifications`) from the repository.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

- `watchCertificationsChanges()` becomes `TableUpdateQuery.allOf([onTable(certifications), onTable(documents), onTable(documentPages)])`.
- In create/update companions, drop `photoFront` / `photoBack` (never written again). After the insert/update:

```dart
      // Card images live in the certification's card document (#2613).
      await DocumentRepository().saveCardImages(
        certificationId: id,
        diverId: cert.diverId ?? await _diverIdForCardOf(cert),
        front: cert.photoFront,
        back: cert.photoBack,
      );
```

```dart
  /// A buddy's card is filed under the diver who owns the buddy; an
  /// ownerless legacy cert under the default diver.
  Future<String> _diverIdForCardOf(domain.Certification cert) async {
    if (cert.buddyId != null) {
      final row = await (_db.select(
        _db.buddies,
      )..where((t) => t.id.equals(cert.buddyId!))).getSingleOrNull();
      if (row?.diverId != null) return row!.diverId!;
    }
    final fallback = await _db
        .customSelect(
          'SELECT id FROM divers ORDER BY is_default DESC, created_at LIMIT 1',
        )
        .getSingle();
    return fallback.read<String>('id');
  }
```

- Every read path that maps rows to entities (`_mapQueryRowToCertification`, `_mapRowToCertification` and the list methods that call them): stop reading `photo_front` / `photo_back`; after mapping a batch, overlay:

```dart
  Future<List<domain.Certification>> _withCardImages(
    List<domain.Certification> certs,
  ) async {
    if (certs.isEmpty) return certs;
    final images = await DocumentRepository().cardImagesFor([
      for (final c in certs) c.id,
    ]);
    return [
      for (final c in certs)
        images[c.id] == null
            ? c
            : domain.Certification(
                // Rebuild with the photos: copyWith cannot set null, and
                // these rows were mapped without photos.
                id: c.id,
                diverId: c.diverId,
                buddyId: c.buddyId,
                name: c.name,
                agency: c.agency,
                level: c.level,
                additionalCredentials: c.additionalCredentials,
                cardNumber: c.cardNumber,
                issueDate: c.issueDate,
                expiryDate: c.expiryDate,
                instructorName: c.instructorName,
                instructorNumber: c.instructorNumber,
                instructorId: c.instructorId,
                photoFront: images[c.id]!.front,
                photoBack: images[c.id]!.back,
                notes: c.notes,
                createdAt: c.createdAt,
                updatedAt: c.updatedAt,
              ),
    ];
  }
```

Copy the constructor argument list from `certification.dart:72-91` exactly (field names as declared there, including `courseId` if present).

- `replaceBuddyCertifications` (`:144`, `:168`) creates certs through `createCertification`, so card images follow automatically.

- [ ] **Step 4: Run the certification suites and the PDF test**

Run: `flutter test test/features/certifications test/features/certification_agencies test/core/services/pdf_templates`
Expected: PASS; fixtures that inserted `photo_front` directly into the table must seed a card document via `DocumentRepository().saveCardImages` instead.

- [ ] **Step 5: Commit**

```bash
git add lib/features/certifications test/features/certifications test/features/certification_agencies test/core/services/pdf_templates
git commit -m "feat(documents): keep certification card images in the card document"
```

---

### Task 9: Providers and mutations

**Files:**
- Create: `lib/features/documents/presentation/providers/document_providers.dart`
- Test: `test/features/documents/presentation/providers/document_providers_test.dart`

**Interfaces:**
- Consumes: `DocumentRepository`, `currentDiverIdProvider` / `validatedCurrentDiverIdProvider`, `notificationSchedulerProvider` (Task 17 adds `updateForDocument`; until then the call is added in Task 17).
- Produces:
  - `documentRepositoryProvider` (`Provider<DocumentRepository>`)
  - `documentsForOwnerProvider` (`FutureProvider.family<List<Document>, DocumentOwner>`)
  - `allDocumentsProvider` (`FutureProvider<List<DocumentListEntry>>`, current diver)
  - `documentByIdProvider` (`FutureProvider.family<Document?, String>`)
  - `documentPagesProvider` (`FutureProvider.family<List<DocumentPage>, String>`)
  - `documentFirstPageProvider` (`FutureProvider.family<DocumentPage?, String>`)
  - `attentionDocumentsProvider` (`FutureProvider<List<(Document, DocumentExpiryStatus)>>`, current diver, excluding insurance, sorted expired first then by days left)
  - `documentMutationsProvider` (`Provider<DocumentMutations>`) with `Future<Document> save(Document, List<DocumentPage>)` and `Future<void> delete(String id)`

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/documents/presentation/providers/document_providers_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, is_default, created_at, updated_at) "
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('attention list excludes insurance, sorts expired first', () async {
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(container.dispose);
    final now = DateTime.now();
    final mutations = container.read(documentMutationsProvider);
    Future<void> add(DocumentType type, DateTime expiry, String title) =>
        mutations.save(
          Document(
            id: '',
            diverId: 'd1',
            owner: const DocumentOwner.personal(),
            type: type,
            title: title,
            expiryDate: expiry,
            createdAt: now,
            updatedAt: now,
          ),
          const [],
        );
    await add(DocumentType.insurance, DateTime(now.year, now.month, now.day - 1), 'ins');
    await add(DocumentType.permit, DateTime(now.year, now.month, now.day + 5), 'permit');
    await add(DocumentType.medicalClearance, DateTime(now.year, now.month, now.day - 2), 'med');
    await add(DocumentType.other, DateTime(now.year + 2, 1, 1), 'far');
    final list = await container.read(attentionDocumentsProvider.future);
    expect([for (final (d, _) in list) d.title], ['med', 'permit']);
  });
}
```

Use the provider the app actually resolves the active diver with (`validatedCurrentDiverIdProvider` or `currentDiverIdProvider`; check which `certification_providers.dart` uses for its diver scoping and mirror it).

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

```dart
// lib/features/documents/presentation/providers/document_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(),
);

final documentsForOwnerProvider =
    FutureProvider.family<List<Document>, DocumentOwner>((ref, owner) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repo.getForOwner(owner, diverId: diverId);
    });

final allDocumentsProvider = FutureProvider<List<DocumentListEntry>>((
  ref,
) async {
  final repo = ref.watch(documentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];
  return repo.getAllForDiver(diverId);
});

final documentByIdProvider = FutureProvider.family<Document?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(documentRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchChanges());
  return repo.getById(id);
});

final documentPagesProvider =
    FutureProvider.family<List<DocumentPage>, String>((ref, id) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getPages(id);
    });

final documentFirstPageProvider =
    FutureProvider.family<DocumentPage?, String>((ref, id) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      return repo.getFirstPage(id);
    });

/// Non-insurance documents of the active diver that are expired or due,
/// expired first, then soonest. Insurance has its own chip.
final attentionDocumentsProvider =
    FutureProvider<List<(Document, DocumentExpiryStatus)>>((ref) async {
      final repo = ref.watch(documentRepositoryProvider);
      ref.invalidateSelfWhen(repo.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      final now = DateTime.now();
      final out = [
        for (final d in await repo.getRemindingForDiver(diverId))
          if (d.type != DocumentType.insurance)
            (d, documentExpiryStatus(d, now)),
      ].where((e) => e.$2.needsAttention).toList();
      out.sort((a, b) => a.$2.daysLeft!.compareTo(b.$2.daysLeft!));
      return out;
    });

class DocumentMutations {
  final Ref _ref;
  DocumentMutations(this._ref);

  DocumentRepository get _repo => _ref.read(documentRepositoryProvider);

  Future<Document> save(Document document, List<DocumentPage> pages) async {
    final saved = await _repo.save(document, pages);
    await _afterChange(saved);
    return saved;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await _afterChange(null, deletedId: id);
  }

  /// Reminders follow every change (Task 17 fills this in).
  Future<void> _afterChange(Document? saved, {String? deletedId}) async {}
}

final documentMutationsProvider = Provider<DocumentMutations>(
  (ref) => DocumentMutations(ref),
);
```

- [ ] **Step 4: Run, expect PASS; commit**

```bash
git add lib/features/documents/presentation/providers test/features/documents/presentation/providers
git commit -m "feat(documents): document providers"
```

---

### Task 10: Page capture service

**Files:**
- Create: `lib/features/documents/data/services/document_page_capture.dart`
- Test: `test/features/documents/data/services/document_page_capture_test.dart`

**Interfaces:**
- Produces:
  - `sealed class PageCaptureResult` with `PageCaptured(DocumentPage page)`, `PageCaptureCancelled()`, `PageCaptureTooLarge(int sizeBytes)`, `PageCaptureUnsupported(String extension)`, `PageCaptureUndecodable()`, `PageCaptureImageTooLarge()`.
  - `class DocumentPageCapture { DocumentPageCapture({ImagePickFn? pickImage, FilePickFn? pickFile, ImageEncodeFn? encode}); Future<PageCaptureResult> fromImage(ImageSource source, {DocumentPageSide? side}); Future<PageCaptureResult> fromFile({DocumentPageSide? side}); }`
  - typedefs `ImagePickFn = Future<({Uint8List bytes, String name})?> Function(ImageSource)`, `FilePickFn = Future<({Uint8List bytes, String name})?> Function(List<String> extensions)`.

- [ ] **Step 1: Write the failing tests** (fakes for all three seams)

```dart
// test/features/documents/data/services/document_page_capture_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

void main() {
  test('camera image is re-encoded to jpeg with the side kept', () async {
    final capture = DocumentPageCapture(
      pickImage: (_) async => (bytes: Uint8List(50), name: 'IMG.HEIC'),
      encode: (picked) async =>
          (outcome: ImageEncodeOutcome.encoded, bytes: Uint8List.fromList([7, 7])),
    );
    final r = await capture.fromImage(
      ImageSource.camera,
      side: DocumentPageSide.front,
    );
    r as PageCaptured;
    expect(r.page.mimeType, 'image/jpeg');
    expect(r.page.bytes, [7, 7]);
    expect(r.page.side, DocumentPageSide.front);
    expect(r.page.fileName, 'IMG.jpg');
  });

  test('cancelled picks report cancelled', () async {
    final capture = DocumentPageCapture(pickImage: (_) async => null);
    expect(
      await capture.fromImage(ImageSource.gallery),
      isA<PageCaptureCancelled>(),
    );
  });

  test('undecodable image is refused', () async {
    final capture = DocumentPageCapture(
      pickImage: (_) async => (bytes: Uint8List(5), name: 'a.jpg'),
      encode: (picked) async =>
          (outcome: ImageEncodeOutcome.undecodable, bytes: null),
    );
    expect(
      await capture.fromImage(ImageSource.gallery),
      isA<PageCaptureUndecodable>(),
    );
  });

  test('a PDF over 10 MB is refused, at 10 MB accepted as-is', () async {
    final over = DocumentPageCapture(
      pickFile: (_) async =>
          (bytes: Uint8List(kMaxDocumentPageBytes + 1), name: 'a.pdf'),
    );
    expect(await over.fromFile(), isA<PageCaptureTooLarge>());
    final at = DocumentPageCapture(
      pickFile: (_) async =>
          (bytes: Uint8List(kMaxDocumentPageBytes), name: 'a.pdf'),
    );
    final r = await at.fromFile() as PageCaptured;
    expect(r.page.mimeType, 'application/pdf');
  });

  test('a picked png file goes through the image encoder', () async {
    var encoded = false;
    final capture = DocumentPageCapture(
      pickFile: (_) async => (bytes: Uint8List(5), name: 'scan.png'),
      encode: (picked) async {
        encoded = true;
        return (outcome: ImageEncodeOutcome.encoded, bytes: Uint8List.fromList([1]));
      },
    );
    await capture.fromFile();
    expect(encoded, isTrue);
  });

  test('unsupported extension is refused', () async {
    final capture = DocumentPageCapture(
      pickFile: (_) async => (bytes: Uint8List(5), name: 'track.gpx'),
    );
    expect(await capture.fromFile(), isA<PageCaptureUnsupported>());
  });
}
```

The seam returns the record `EncodedImage = ({ImageEncodeOutcome outcome, Uint8List? bytes})`, so fakes need no codec types beyond the `ImageEncodeOutcome` enum (`profile_photo_codec.dart`; confirm the value names `encoded`, `tooLarge`, `undecodable` there). The production encoder adapts `encodeStoredImage`'s result into that record.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

```dart
// lib/features/documents/data/services/document_page_capture.dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/files/picked_file_materializer.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

typedef PickedBytes = ({Uint8List bytes, String name});
typedef ImagePickFn = Future<PickedBytes?> Function(ImageSource source);
typedef FilePickFn = Future<PickedBytes?> Function(List<String> extensions);
typedef EncodedImage = ({ImageEncodeOutcome outcome, Uint8List? bytes});
typedef ImageEncodeFn = Future<EncodedImage> Function(PickedBytes picked);

sealed class PageCaptureResult {
  const PageCaptureResult();
}

class PageCaptured extends PageCaptureResult {
  final DocumentPage page;
  const PageCaptured(this.page);
}

class PageCaptureCancelled extends PageCaptureResult {
  const PageCaptureCancelled();
}

class PageCaptureTooLarge extends PageCaptureResult {
  final int sizeBytes;
  const PageCaptureTooLarge(this.sizeBytes);
}

class PageCaptureUnsupported extends PageCaptureResult {
  final String extension;
  const PageCaptureUnsupported(this.extension);
}

class PageCaptureUndecodable extends PageCaptureResult {
  const PageCaptureUndecodable();
}

/// The source image has more pixels than the encoder accepts.
class PageCaptureImageTooLarge extends PageCaptureResult {
  const PageCaptureImageTooLarge();
}

class DocumentPageCapture {
  final ImagePickFn _pickImage;
  final FilePickFn _pickFile;
  final ImageEncodeFn _encode;

  DocumentPageCapture({
    ImagePickFn? pickImage,
    FilePickFn? pickFile,
    ImageEncodeFn? encode,
  }) : _pickImage = pickImage ?? _platformPickImage,
       _pickFile = pickFile ?? _platformPickFile,
       _encode = encode ?? _platformEncode;

  Future<PageCaptureResult> fromImage(
    ImageSource source, {
    DocumentPageSide? side,
  }) async {
    final picked = await _pickImage(source);
    if (picked == null) return const PageCaptureCancelled();
    return _encodeImage(picked, side);
  }

  Future<PageCaptureResult> fromFile({DocumentPageSide? side}) async {
    final picked = await _pickFile(kDocumentPickerExtensions);
    if (picked == null) return const PageCaptureCancelled();
    final verdict = checkDocumentFile(
      fileName: picked.name,
      sizeBytes: picked.bytes.length,
    );
    return switch (verdict) {
      DocumentFileUnsupported(:final extension) => PageCaptureUnsupported(
        extension,
      ),
      DocumentFileTooLarge(:final sizeBytes) => PageCaptureTooLarge(sizeBytes),
      DocumentFileAccepted(needsImageReencode: true) => await _encodeImage(
        picked,
        side,
      ),
      DocumentFileAccepted(:final mimeType) => PageCaptured(
        _page(picked.name, mimeType, picked.bytes, side),
      ),
    };
  }

  Future<PageCaptureResult> _encodeImage(
    PickedBytes picked,
    DocumentPageSide? side,
  ) async {
    final encoded = await _encode(picked);
    switch (encoded.outcome) {
      case ImageEncodeOutcome.encoded:
        final bytes = encoded.bytes!;
        if (bytes.length > kMaxDocumentPageBytes) {
          return PageCaptureTooLarge(bytes.length);
        }
        final name = '${p.basenameWithoutExtension(picked.name)}.jpg';
        return PageCaptured(_page(name, 'image/jpeg', bytes, side));
      case ImageEncodeOutcome.tooLarge:
        return const PageCaptureImageTooLarge();
      default:
        return const PageCaptureUndecodable();
    }
  }

  DocumentPage _page(
    String name,
    String mime,
    Uint8List bytes,
    DocumentPageSide? side,
  ) {
    final now = DateTime.now();
    return DocumentPage(
      id: '',
      documentId: '',
      pageIndex: 0,
      side: side,
      fileName: name,
      mimeType: mime,
      sizeBytes: bytes.length,
      bytes: bytes,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Desktop pickers ignore maxWidth / imageQuality, so the encoder does the
  // sizing (see certification_edit_page.dart _pickPhoto).
  static Future<PickedBytes?> _platformPickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return null;
    return (bytes: await picked.readAsBytes(), name: picked.name);
  }

  static Future<PickedBytes?> _platformPickFile(List<String> extensions) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (result.isEmpty) return null;
    final local = await materializePickedFiles(result);
    if (local.isEmpty) return null;
    final file = local.first;
    return (bytes: await File(file.path).readAsBytes(), name: file.name);
  }

  static Future<EncodedImage> _platformEncode(PickedBytes picked) async {
    final r = await encodeStoredImage(
      ImageEncodeRequest.fromBytes(
        bytes: picked.bytes,
        spec: ImageEncodeSpec.certificationCard,
        declaredName: picked.name,
      ),
    );
    return (outcome: r.outcome, bytes: r.bytes);
  }
}
```

Add `import 'dart:io';`. Match `FilePicker.pickFiles` result handling to `document_open_helper.dart:99-133` (file_picker 12 returns handles; `materializePickedFiles` turns them into local files and throws `PickedFileMaterializationException`, which the caller in Task 12 reports).

- [ ] **Step 4: Run, expect PASS; commit**

```bash
git add lib/features/documents/data/services test/features/documents/data/services
git commit -m "feat(documents): page capture from camera, gallery and files"
```

---

### Task 11: Shared widgets: badge, thumbnail, tile, page viewer, external opener

**Files:**
- Create: `lib/features/documents/presentation/document_l10n.dart`
- Create: `lib/features/documents/presentation/widgets/document_expiry_badge.dart`
- Create: `lib/features/documents/presentation/widgets/document_page_thumbnail.dart`
- Create: `lib/features/documents/presentation/widgets/document_tile.dart`
- Create: `lib/features/documents/presentation/widgets/document_page_viewer.dart`
- Create: `lib/features/documents/presentation/helpers/document_page_opener.dart`
- Test: `test/features/documents/presentation/widgets/document_widgets_test.dart`

**Interfaces:**
- Produces:
  - `String documentTypeLabel(AppLocalizations l10n, DocumentType t)`, `IconData documentTypeIcon(DocumentType t)`, `String documentOwnerKindLabel(AppLocalizations l10n, DocumentOwnerKind k)`, `String documentDisplayTitle(AppLocalizations l10n, Document d)` (title, else type label)
  - `DocumentExpiryBadge({required DocumentExpiryStatus status})` (renders nothing for none/ok)
  - `DocumentPageThumbnail({required String documentId, double size = 48})` (watches `documentFirstPageProvider`; image via `Image.memory`, PDF via `PdfDocumentViewBuilder.data` page 1 or a PDF icon, other via `documentTypeIcon`)
  - `DocumentTile({required Document document, String? ownerLabel, VoidCallback? onTap, Widget? thumbnail})` (`thumbnail` defaults to `DocumentPageThumbnail(documentId: document.id)`; tests inject a plain widget)
  - `DocumentPageViewer({required List<DocumentPage> pages})` (PageView; images with `InteractiveViewer`; PDFs with `PdfViewer.data(bytes, sourceName: page.id)`; other files as a tile with "Open with"; errorBuilder shows `documents_page_cannotDisplay` + "Open with")
  - `Future<void> openDocumentPageExternally(BuildContext context, DocumentPage page)`

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/features/documents/presentation/widgets/document_widgets_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';

import '../../../../helpers/test_app.dart';

DocumentPage textPage() => DocumentPage(
  id: 'p1',
  documentId: 'x',
  pageIndex: 0,
  fileName: 'policy.docx',
  mimeType:
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  sizeBytes: 3,
  bytes: Uint8List.fromList([1, 2, 3]),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('badge shows expired and due-soon, nothing when ok', (t) async {
    await t.pumpWidget(
      testApp(
        child: const Column(
          children: [
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.expired, -3),
            ),
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.dueSoon, 5),
            ),
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.ok, 90),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Expires in 5 days'), findsOneWidget);
    expect(find.textContaining('90'), findsNothing);
  });

  testWidgets('tile falls back to the type name for an empty title',
      (t) async {
    await t.pumpWidget(
      testApp(
        child: DocumentTile(
          document: Document(
            id: 'x',
            diverId: 'd',
            owner: const DocumentOwner.personal(),
            type: DocumentType.medicalClearance,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          ownerLabel: null,
          thumbnail: const SizedBox(),
        ),
      ),
    );
    expect(find.text('Medical clearance'), findsOneWidget);
  });

  testWidgets('viewer shows a Word page as a file tile with Open with',
      (t) async {
    await t.pumpWidget(testApp(child: DocumentPageViewer(pages: [textPage()])));
    expect(find.text('policy.docx'), findsOneWidget);
    expect(find.text('Open with...'), findsOneWidget);
  });

  testWidgets('viewer shows a placeholder for a corrupt image', (t) async {
    final broken = DocumentPage(
      id: 'p2',
      documentId: 'x',
      pageIndex: 0,
      fileName: 'front.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 2,
      bytes: Uint8List.fromList([0, 1]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await t.pumpWidget(testApp(child: DocumentPageViewer(pages: [broken])));
    await t.pumpAndSettle();
    expect(find.text("Can't display this page"), findsOneWidget);
  });
}
```

`DocumentTile` takes an injectable `thumbnail` widget (default `DocumentPageThumbnail(documentId: document.id)`) so the tile test needs no provider.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

`document_l10n.dart`: two exhaustive switches over `DocumentType` (labels `documents_type_*`; icons: insurance `Icons.health_and_safety_outlined`, medicalClearance `Icons.medical_information_outlined`, certificationCard `Icons.card_membership_outlined`, permit `Icons.verified_outlined`, booking `Icons.confirmation_number_outlined`, receipt `Icons.receipt_long_outlined`, manual `Icons.menu_book_outlined`, map `Icons.map_outlined`, other `Icons.description_outlined`) and one over `DocumentOwnerKind` (`documents_owner_*`).

`document_expiry_badge.dart`:

```dart
class DocumentExpiryBadge extends StatelessWidget {
  final DocumentExpiryStatus status;
  const DocumentExpiryBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (String text, Color bg, Color fg) = switch (status.kind) {
      DocumentExpiryKind.expired => (
        l10n.documents_badge_expired,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      DocumentExpiryKind.dueSoon => (
        l10n.documents_badge_expiresInDays(status.daysLeft!),
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _ => ('', Colors.transparent, Colors.transparent),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
```

Check `test/architecture/` and `lib/core/theme/` for a colour-token rule (some screens must use `AppColors`/theme extensions rather than raw `Colors.*`); `Colors.transparent` is used only in the empty branch, which returns early.

`document_tile.dart`: a `ListTile` with `leading: thumbnail`, `title: documentDisplayTitle`, `subtitle:` owner label and issuer joined with " . " (`[ownerLabel, document.issuer].whereType<String>().join(' · ')`), `trailing: DocumentExpiryBadge(status: documentExpiryStatus(document, DateTime.now()))`, `onTap`.

`document_page_viewer.dart`: `StatefulWidget` with a `PageController`; a counter `documents_page_counter(current, total)` above when `pages.length > 1`; per page:

```dart
  Widget _page(BuildContext context, DocumentPage page) {
    final bytes = page.bytes;
    if (bytes == null) return _fileTile(context, page);
    if (page.isImage) {
      return InteractiveViewer(
        maxScale: 6,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, _, _) => _cannotDisplay(context, page),
        ),
      );
    }
    if (page.isPdf) {
      return PdfViewer.data(
        bytes,
        sourceName: 'document-page-${page.id}',
        params: PdfViewerParams(
          errorBannerBuilder: (context, error, stack, ref) =>
              _cannotDisplay(context, page),
        ),
      );
    }
    return _fileTile(context, page);
  }
```

Match `PdfViewer.data` / `PdfViewerParams` names to the call in `document_viewer_page.dart:100`. `_fileTile` shows `documentTypeIcon`-style file icon, `page.fileName`, a formatted size, and a `FilledButton.tonal(onPressed: () => openDocumentPageExternally(context, page), child: Text(l10n.documents_page_openWith))`. `_cannotDisplay` shows `Icons.broken_image_outlined`, `documents_page_cannotDisplay`, and the same button.

`document_page_opener.dart`: follow `DocumentOpenHelper.openExternally` (`document_open_helper.dart:55-88`): write `page.bytes` to `p.join((await getTemporaryDirectory()).path, 'documents', page.fileName)` (create the folder), then `open` / `cmd /c start` / `xdg-open` on desktop, `SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: page.mimeType)], sharePositionOrigin: shareAnchorFrom(context)))` on mobile.

- [ ] **Step 4: Run, expect PASS; commit**

```bash
git add lib/features/documents/presentation test/features/documents/presentation/widgets
git commit -m "feat(documents): badge, tile, thumbnail and page viewer"
```

---

### Task 12: Document editor page

**Files:**
- Create: `lib/features/documents/presentation/widgets/document_page_strip.dart`
- Create: `lib/features/documents/presentation/pages/document_edit_page.dart`
- Test: `test/features/documents/presentation/pages/document_edit_page_test.dart`

**Interfaces:**
- Consumes: `documentMutationsProvider`, `documentByIdProvider`, `documentPagesProvider`, `DocumentPageCapture`, `validatedCurrentDiverIdProvider`.
- Produces:
  - `DocumentEditPage({String? documentId, DocumentOwner owner = const DocumentOwner.personal(), DocumentType? initialType, bool embedded = false, VoidCallback? onSaved, VoidCallback? onCancel, @visibleForTesting DocumentPageCapture? capture})`
  - `DocumentPageStrip({required List<DocumentPage> pages, required bool cardSlots, required ValueChanged<List<DocumentPage>> onChanged, required Future<DocumentPage?> Function(DocumentPageSide? side) onAdd})`

- [ ] **Step 1: Write the failing editor tests**

Cover, each as its own `testWidgets` using `testApp` + `getBaseOverrides()` + an in-memory DB (`setUpTestDatabase`) with diver `d1`, and a fake `DocumentPageCapture(pickImage: ..., pickFile: ..., encode: ...)`:

```dart
  testWidgets('insurance shows phones and primary toggle; permit does not',
      (t) async {
    await pumpEditor(t, initialType: DocumentType.insurance);
    expect(find.text('24-hour emergency line'), findsOneWidget);
    expect(find.text('Primary insurance'), findsOneWidget);
    await pumpEditor(t, initialType: DocumentType.permit);
    expect(find.text('24-hour emergency line'), findsNothing);
  });

  testWidgets('card type shows Front and Back slots and no expiry',
      (t) async {
    await pumpEditor(t, initialType: DocumentType.certificationCard);
    expect(find.text('Front'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Expires'), findsNothing);
  });

  testWidgets('adding pages from a file and saving persists them in order',
      (t) async {
    await pumpEditor(t, initialType: DocumentType.permit, capture: fakeFiles());
    await t.tap(find.text('Add page'));
    await t.pumpAndSettle();
    await t.tap(find.text('Choose file'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('document-title')), 'Marine park');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    final docs = await DocumentRepository().getAllForDiver('d1');
    expect(docs.single.document.title, 'Marine park');
    expect(docs.single.pageCount, 1);
  });

  testWidgets('a too-large file shows the limit and adds nothing', (t) async {
    await pumpEditor(t, capture: tooLargeFile());
    await t.tap(find.text('Add page'));
    await t.pumpAndSettle();
    await t.tap(find.text('Choose file'));
    await t.pumpAndSettle();
    expect(find.textContaining('10 MB'), findsOneWidget);
  });

  testWidgets('removing a page then saving deletes it', (t) async { ... });

  testWidgets('editing an existing document keeps its owner', (t) async { ... });
```

Write `pumpEditor`, `fakeFiles` and `tooLargeFile` helpers at the top of the file; write the last two tests in full when implementing (seed via `DocumentRepository().save`, open with `documentId:`).

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement the page strip**

A horizontal `ReorderableListView` (`scrollDirection: Axis.horizontal`, `buildDefaultDragHandles: false` with `ReorderableDragStartListener` per tile) of 120x76 cards (`AspectRatio(1.586)` like the cert slot) built with `DocumentPageThumbnail`-style rendering from in-memory bytes (image `Image.memory`; PDF/other an icon + file name), each with a top-right remove `IconButton(Icons.close, tooltip: l10n.documents_pages_remove)`. When `cardSlots` is true, the first two tiles are fixed Front and Back slots (labelled, tap to add or replace, not reorderable) and further pages follow. A trailing "Add page" tile opens a bottom sheet with Take photo / Choose photo / Choose file (camera hidden on desktop: `Platform.isAndroid || Platform.isIOS`). `onChanged` receives the new list with `pageIndex` re-numbered.

- [ ] **Step 4: Implement the editor**

Shape it like `InsuranceEditPage` / `CertificationEditPage`: `ConsumerStatefulWidget`, `_formKey`, controllers wired to `_onFieldChanged`, `_hasChanges`, `_isSaving`, `PopScope(canPop: !_hasChanges)` with the discard dialog, `AppBarTextAction(label: l10n.divers_edit_saveButton)`. Body `SingleChildScrollView > Column`:

1. Type dropdown (`DropdownButtonFormField<DocumentType>`): all types except `certificationCard` unless the document already is one or `initialType` is one (a card is created from the certification).
2. Title (`Key('document-title')`), hint = type label.
3. Issuer (label `documents_field_issuerInsurance` for insurance, else `documents_field_issuer`).
4. Number (`documents_field_referenceNumberInsurance` for insurance).
5. Insurance only: emergency phone, office phone (`keyboardType: TextInputType.phone`), `SwitchListTile` primary with subtitle.
6. Issue date and expiry date via `showAppDatePicker` (`lib/shared/widgets/app_date_picker.dart`) with clear buttons; expiry hidden for card type.
7. Reminder lead: `DropdownButtonFormField<int>` over `[0, 7, 14, 30, 60, 90]` labelled with `documents_field_reminderLeadDays`; hidden for card type and when no expiry.
8. Pages: `DocumentPageStrip` with `cardSlots: type == certificationCard || type == insurance`.
9. Notes (multi-line).

Page add handler maps `PageCaptureResult` to the strip or a SnackBar: `PageCaptureTooLarge` -> `documents_pages_tooLarge(formatBytes(size))`, `PageCaptureUnsupported` -> `documents_pages_unsupported(ext)`, `PageCaptureImageTooLarge` -> `profilePhoto_error_tooLarge`, `PageCaptureUndecodable` -> `profilePhoto_error_undecodable`, cancel -> nothing. Wrap in try/catch: `PickedFileMaterializationException` and others -> `media_import_failedToImportError('$e')`.

Save builds the `Document` (`id: widget.documentId ?? ''`, `diverId` from the loaded document or `validatedCurrentDiverIdProvider`, `owner` from the loaded document or `widget.owner`) and calls `documentMutationsProvider.save(doc, _pages)` inside try/catch; success -> SnackBar `documents_saved` then `onSaved` or `context.pop()`; failure -> SnackBar `documents_error_save('$e')`, keep the form.

If the file goes past ~400 lines, move the field column to `widgets/document_form_fields.dart`.

- [ ] **Step 5: Run, expect PASS; commit**

```bash
git add lib/features/documents/presentation test/features/documents/presentation/pages/document_edit_page_test.dart
git commit -m "feat(documents): document editor with page strip"
```

---

### Task 13: Detail page, global Documents page, nav entry and routes

**Files:**
- Create: `lib/features/documents/presentation/pages/document_detail_page.dart`
- Create: `lib/features/documents/presentation/widgets/documents_expiring_strip.dart`
- Create: `lib/features/documents/presentation/pages/documents_page.dart`
- Modify: `lib/shared/widgets/nav/nav_destinations.dart:104-110` (after certifications)
- Modify: `lib/core/theme/feature_accent_colors.dart:25-46`, `~:76`
- Modify: `lib/core/router/app_router.dart:775-811` (after certifications)
- Modify: `test/shared/widgets/nav/nav_destinations_test.dart:13-14,35-55,77-99`, `test/shared/widgets/nav/rail_destination_order_test.dart:10-28`
- Test: `test/features/documents/presentation/pages/documents_page_test.dart`, `document_detail_page_test.dart`, `test/core/router/app_router_test.dart` (add `/documents` routes)

**Interfaces:**
- Produces: routes `/documents` (`DocumentsPage`, query `type=<DocumentType.name>`, `filter=expiring`, `owner=personal`, `selected=<id>`), `/documents/new` (query `ownerKind`, `ownerId`, `type`), `/documents/:documentId`, `/documents/:documentId/edit`.

- [ ] **Step 1: Write the failing page tests**

```dart
  testWidgets('groups by owner kind with an expiring strip', (t) async {
    // Seed: personal insurance (ok), personal clearance (expired), trip
    // permit (due in 5 days). Pump DocumentsPage on a phone size.
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
  });

  testWidgets('search filters by title, issuer and number', (t) async {
    await t.enterText(find.byType(TextField), 'DAN');
    await t.pumpAndSettle();
    // only the insurance with issuer DAN remains
  });

  testWidgets('type filter from the route query shows only insurance',
      (t) async { /* DocumentsPage(initialType: DocumentType.insurance) */ });

  testWidgets('detail shows pages, metadata, owner link; delete confirms',
      (t) async { /* DocumentDetailPage(documentId: ...) */ });
```

Write each with the seeding and expectations spelled out in full when implementing, following `certification_detail_page_test.dart:33-86` (GoRouter host, `getBaseOverrides`, sized view).

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Nav destination**

```dart
  NavDestination(
    id: 'documents',
    route: '/documents',
    icon: Icons.folder_copy_outlined,
    selectedIcon: Icons.folder_copy,
    label: (l10n) => l10n.nav_documents,
  ),
```

Insert directly after the `certifications` entry. Saved orders get it appended (`normalizeNavOrder`); on a fresh install it falls past the phone's first three slots, so it lands in More. Update `nav_destinations_test.dart` (length 17 -> 18, the id lists, `movableNavIds.length` 15 -> 16), `rail_destination_order_test.dart` (`('documents', '/documents')` after certifications), and add `'documents': Color(0xFF0F766E)` (light) and `'documents': Color(0xFF5EEAD4)` (dark) in `feature_accent_colors.dart`, checking contrast with the test there.

- [ ] **Step 4: Routes** (after the certifications `GoRoute`)

```dart
          GoRoute(
            path: '/documents',
            name: 'documents',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: DocumentsPage(
                initialType: DocumentType.values.asNameMap()[
                    state.uri.queryParameters['type']],
                initialExpiringOnly:
                    state.uri.queryParameters['filter'] == 'expiring',
                initialPersonalOnly:
                    state.uri.queryParameters['owner'] == 'personal',
              ),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newDocument',
                builder: (context, state) {
                  final q = state.uri.queryParameters;
                  final kind = DocumentOwnerKind.fromStorage(q['ownerKind']);
                  final ownerId = q['ownerId'];
                  return DocumentEditPage(
                    owner: kind == DocumentOwnerKind.personal || ownerId == null
                        ? const DocumentOwner.personal()
                        : DocumentOwner(kind, ownerId),
                    initialType: DocumentType.values.asNameMap()[q['type']],
                  );
                },
              ),
              GoRoute(
                path: ':documentId',
                name: 'documentDetail',
                builder: (context, state) => DocumentDetailPage(
                  documentId: state.pathParameters['documentId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editDocument',
                    builder: (context, state) => DocumentEditPage(
                      documentId: state.pathParameters['documentId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
```

Add `/documents`, `/documents/new`, `/documents/x` and `/documents/x/edit` to `app_router_test` where the other chip destinations are listed.

- [ ] **Step 5: Detail page**

`ConsumerWidget` with `documentId`, `embedded`, `onDeleted`; mirror the certification detail redirect (`certification_detail_page.dart:50-61`) to `/documents?selected=$id` on wide screens when not embedded. Body: `documentPagesProvider` -> `SizedBox(height: 320, child: DocumentPageViewer(pages: pages))` (tap opens a full-screen route with the same viewer), then a `Card` of rows (type, issuer, number, issued, expires + badge, insurance phones as tappable `tel:` links via `url_launcher` like the emergency card, primary flag, notes), and an owner row `documents_detail_owner` that navigates to the owner (`/dives/<id>`, `/sites/<id>`, `/trips/<id>`, `/equipment/<id>`, `/courses/<id>`, `/certifications/<id>`, `/buddies/<id>`, `/dive-centers/<id>`; read each prefix from `app_router.dart`). AppBar actions: edit (`/documents/<id>/edit`) and delete (confirm dialog `documents_delete_title` / `_content`, then `documentMutationsProvider.delete`, SnackBar `documents_deleted`, `onDeleted` or pop).

- [ ] **Step 6: Global page**

`ConsumerStatefulWidget` mirroring `certification_list_page.dart:32-228` without table mode: `MasterDetailScaffold(sectionId: 'documents', masterBuilder: ... _DocumentsListContent ..., detailBuilder: DocumentDetailPage(embedded: true), summaryBuilder: none or a small empty-state widget, editBuilder: DocumentEditPage(embedded: true), createBuilder: DocumentEditPage(embedded: true), floatingActionButton: fab)` when `ResponsiveBreakpoints.isMasterDetail(context)`, else the list content with an AppBar and the FAB (`context.push('/documents/new')`).

List content: `allDocumentsProvider` -> filter by search text (title, issuer, referenceNumber; case-insensitive), the type chip row (`FilterChip` per type present, plus All), and the initial flags; then `CustomScrollView` with `DocumentsExpiringStrip` (horizontal cards for entries whose status needs attention, any type including insurance) and one `SliverList` section per `DocumentOwnerKind` that has entries, headed by `documentOwnerKindLabel`, rows `DocumentTile(document, ownerLabel, onTap: select or push)`. Empty: `documents_empty` with the add button.

- [ ] **Step 7: Run page, nav, router and theme tests, expect PASS**

Run: `flutter test test/features/documents test/shared/widgets/nav test/core/router test/core/theme`

- [ ] **Step 8: Commit**

```bash
git add lib/features/documents lib/shared/widgets/nav lib/core/theme lib/core/router test/features/documents test/shared/widgets/nav test/core/router
git commit -m "feat(documents): documents page, detail, nav entry and routes"
```

---

### Task 14: Documents section on the eight owner pages

**Files:**
- Create: `lib/features/documents/presentation/widgets/documents_section.dart`
- Modify: `lib/core/constants/dive_detail_sections.dart:18-42` (add `documents` after `notes`, plus displayName/icon switch arms)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:546-548` (section map entry)
- Modify: `lib/core/constants/site_detail_sections.dart:19-37` and `lib/features/dive_sites/presentation/pages/site_detail_page.dart:388-389`
- Modify: `lib/features/trips/presentation/widgets/overview/trip_prepare_overview.dart:68`, `lib/features/trips/presentation/widgets/story/trip_story_view.dart:176`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:288`
- Modify: `lib/features/courses/presentation/pages/course_detail_page.dart:251`
- Modify: `lib/features/certifications/presentation/pages/certification_detail_page.dart:172-174`
- Modify: `lib/features/buddies/presentation/pages/buddy_detail_page.dart:164`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart:113`
- Test: `test/features/documents/presentation/widgets/documents_section_test.dart`; run each owner page's existing tests

**Interfaces:**
- Produces: `DocumentsSection({required DocumentOwner owner, bool excludeCards = false})`.

- [ ] **Step 1: Write the failing section test**

```dart
  testWidgets('lists the owner documents and Add opens the editor with the owner',
      (t) async {
    // Override documentsForOwnerProvider(DocumentOwner(trip, 't1')) with two
    // documents; host DocumentsSection in a GoRouter with a /documents/new
    // route that records state.uri.
    expect(find.text('Documents'), findsOneWidget);
    expect(find.byType(DocumentTile), findsNWidgets(2));
    await t.tap(find.text('Add document'));
    await t.pumpAndSettle();
    expect(recordedUri, Uri.parse('/documents/new?ownerKind=trip&ownerId=t1'));
  });

  testWidgets('certification section hides the card document', (t) async {
    // excludeCards: true and one certificationCard + one other -> 1 tile
  });

  testWidgets('empty owner shows the empty line', (t) async {});
```

Write all three in full when implementing.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement the section** (modelled on `equipment_documents_section.dart`)

```dart
class DocumentsSection extends ConsumerWidget {
  final DocumentOwner owner;

  /// The certification page shows its card images itself.
  final bool excludeCards;

  const DocumentsSection({
    super.key,
    required this.owner,
    this.excludeCards = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final docs = ref.watch(documentsForOwnerProvider(owner));
    return Card(
      key: ValueKey('documents-section-${owner.kind.name}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_copy_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.documents_section_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('documents-section-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.documents_add),
                  onPressed: () => context.push(
                    Uri(
                      path: '/documents/new',
                      queryParameters: {
                        'ownerKind': owner.kind.storage,
                        'ownerId': ?owner.id,
                      },
                    ).toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            docs.when(
              data: (list) {
                final shown = excludeCards
                    ? list
                          .where((d) => d.type != DocumentType.certificationCard)
                          .toList()
                    : list;
                if (shown.isEmpty) {
                  return Text(
                    l10n.documents_section_empty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final d in shown)
                      DocumentTile(
                        key: ValueKey('document-${d.id}'),
                        document: d,
                        onTap: () => context.push('/documents/${d.id}'),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                l10n.documents_error_save('$e'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

If the SDK's Dart version lacks null-aware map elements (`'ownerId': ?owner.id`), write `if (owner.id != null) 'ownerId': owner.id!`.

- [ ] **Step 4: Embed in each owner page**

- Dive: enum `DiveDetailSectionId.documents` (displayName via l10n `documents_section_title`, icon `Icons.folder_copy_outlined`); map entry `DiveDetailSectionId.documents: () => [DocumentsSection(owner: DocumentOwner(DocumentOwnerKind.dive, dive.id))]`. Check any test enumerating `DiveDetailSectionId.values` and the saved-order normalizer (an appended id is added automatically).
- Site: same with `SiteDetailSectionId.documents` and `DocumentOwnerKind.site`.
- Trip: append `DocumentsSection(owner: DocumentOwner(DocumentOwnerKind.trip, trip.id))` in `trip_prepare_overview.dart` after the notes card (in a `Padding` matching it) and in `trip_story_view.dart` as a `SliverPadding(sliver: SliverToBoxAdapter(child: DocumentsSection(...)))` before the closing `SizedBox(height: 32)`.
- Equipment: after `:288`, `const SizedBox(height: 24), DocumentsSection(owner: DocumentOwner(DocumentOwnerKind.equipment, equipment.id)),` (the media-based `EquipmentDocumentsSection` stays).
- Course: after the notes card, same shape with `DocumentOwnerKind.course`.
- Certification: after the photos card, `DocumentsSection(owner: DocumentOwner(DocumentOwnerKind.certification, certification.id), excludeCards: true)`.
- Buddy: after notes, `DocumentOwnerKind.buddy`.
- Dive center: after `_NotesSection`, `const Divider(height: 32), DocumentsSection(owner: DocumentOwner(DocumentOwnerKind.diveCenter, center.id)),`.

- [ ] **Step 5: Run the section test and every owner page suite**

Run: `flutter test test/features/documents test/features/dive_log/presentation/pages test/features/dive_sites/presentation test/features/trips/presentation test/features/equipment/presentation test/features/courses/presentation test/features/certifications/presentation test/features/buddies/presentation test/features/dive_centers/presentation test/core/constants`
Expected: PASS. Owner page tests without a database may need `documentsForOwnerProvider.overrideWith((ref, owner) async => const [])` in their overrides; add it to `getBaseOverrides()` in `test/helpers/mock_providers.dart` once instead of per test.

- [ ] **Step 6: Commit**

```bash
git add lib/features lib/core/constants test/features test/core/constants test/helpers/mock_providers.dart
git commit -m "feat(documents): documents section on owner pages"
```

---

### Task 15: Diver profile hub, medical page, insurance page retired

**Files:**
- Modify: `lib/features/settings/presentation/pages/diver_profile_hub_page.dart:258-262` (insurance route) and add a Documents row after it
- Modify: `lib/features/settings/presentation/pages/medical_info_edit_page.dart` (remove `_medicalClearanceExpiry`, `_selectMedicalClearanceExpiry`, `_buildMedicalClearanceField`, and the `medicalClearanceExpiryDate:` in `_save`; add the clearances list)
- Modify: `lib/core/router/app_router.dart:1530-1532` (insurance route redirects)
- Delete: `lib/features/settings/presentation/pages/insurance_edit_page.dart`, `test/features/settings/presentation/pages/insurance_edit_page_test.dart`
- Modify: `lib/features/dashboard/presentation/widgets/gauge_strip.dart:163,174,186,196` (insurance chip taps go to `/documents?type=insurance`)
- Test: `test/features/settings/presentation/pages/diver_profile_hub_page_test.dart`, `medical_info_edit_page_test.dart`, `test/core/router/app_router_test.dart`

- [ ] **Step 1: Update the tests first**

- Hub: tapping Insurance navigates to `/documents?type=insurance`; a Documents row shows `documents_profileHub_documents_count(n)` for personal documents and navigates to `/documents?owner=personal`.
- Medical: no clearance date picker; a "Medical clearances" card lists clearance documents (`documentsForOwnerProvider(DocumentOwner.personal())` filtered to `medicalClearance`) with badges; "Add clearance" pushes `/documents/new?type=medicalClearance`.
- Router: `/settings/diver-profile/insurance` redirects to `/documents?type=insurance`.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

Hub insurance row: `route: '/documents?type=insurance'` (subtitle logic unchanged; it reads the hydrated `diver.insurance`). New row:

```dart
            Consumer(
              builder: (context, ref, _) {
                final personal = ref.watch(
                  documentsForOwnerProvider(const DocumentOwner.personal()),
                );
                return _buildSectionTile(
                  context,
                  icon: Icons.folder_copy_outlined,
                  title: context.l10n.documents_profileHub_documents,
                  subtitle: context.l10n.documents_profileHub_documents_count(
                    personal.value?.length ?? 0,
                  ),
                  route: '/documents?owner=personal',
                );
              },
            ),
            const Divider(height: 1),
```

Router: replace the insurance `GoRoute` builder with `redirect: (context, state) => '/documents?type=insurance'` (keep `path: 'insurance'` and the name so existing deep links resolve).

Medical page: delete the clearance field and state; after the form card add a second `Card` titled `documents_medical_clearances` listing clearance documents as `DocumentTile`s and a `TextButton.icon(label: documents_medical_addClearance)` that pushes `/documents/new?type=medicalClearance`. `_save` no longer passes `medicalClearanceExpiryDate`.

Gauge strip insurance chip: change the four `context.push('/settings/diver-profile/insurance')` calls to `context.push('/documents?type=insurance')` (the redirect would also work; going direct keeps one hop).

Remove the `InsuranceEditPage` import from `app_router.dart` and delete the page and its test.

- [ ] **Step 4: Run, expect PASS**

Run: `flutter test test/features/settings test/core/router test/features/dashboard`

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/settings lib/core/router lib/features/dashboard test/features/settings test/core/router test/features/dashboard
git commit -m "feat(documents): profile hub and medical page use documents"
```

(`-A` on these explicit paths stages the deletions.)

---

### Task 16: Documents home chip

**Files:**
- Modify: `lib/features/dashboard/presentation/providers/gauge_providers.dart:22-38` (enum), `:75-135` (field), `:237-280` (provider)
- Modify: `lib/features/dashboard/presentation/widgets/gauge_strip.dart` (after the certifications block ~311)
- Modify: `lib/features/settings/presentation/pages/home_appearance_page.dart:39-52`
- Test: `test/features/dashboard/presentation/widgets/gauge_strip_test.dart`, `test/features/settings/presentation/pages/home_appearance_page_test.dart`, `test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `attentionDocumentsProvider`.
- Produces: `HomeChipType.documents`; `DashboardGauges.attentionDocuments` (`List<(Document, DocumentExpiryStatus)>`, default `const []`).

- [ ] **Step 1: Write the failing chip tests**

```dart
  testWidgets('one due document names it', (t) async {
    // gauges with attentionDocuments: [(permit 'Marine park', dueSoon 12)]
    expect(find.textContaining('Marine park expires'), findsOneWidget);
  });

  testWidgets('several show a count with alert tone when any expired',
      (t) async {
    expect(find.text('2 documents need attention'), findsOneWidget);
  });

  testWidgets('hidden chip still shows an expired medical clearance',
      (t) async {
    // hiddenHomeChips: {'documents'}, attention: [expired clearance, due permit]
    expect(find.textContaining('expired'), findsOneWidget);
    expect(find.textContaining('Marine park'), findsNothing);
  });

  testWidgets('hidden chip with only a due permit shows nothing', (t) async {});

  testWidgets('tap with one document opens it, with several opens the list',
      (t) async {});
```

Write them in full following the existing insurance chip tests in `gauge_strip_test.dart`.

- [ ] **Step 2: Run, expect FAIL**

- [ ] **Step 3: Implement**

Enum: append `documents` (append-only so stored hide keys never shift). `DashboardGauges`: `final List<(Document, DocumentExpiryStatus)> attentionDocuments;` defaulting to `const []`; provider: `attentionDocuments: await ref.watch(attentionDocumentsProvider.future),`.

Chip block, after certifications:

```dart
    // Documents (issue #2613). An expired medical clearance is hardened like
    // insurance: it renders even with the chip hidden. Everything else
    // follows the hide.
    final docsShown = _shown(hidden, HomeChipType.documents);
    final docs = [
      for (final e in g.attentionDocuments)
        if (docsShown ||
            (e.$1.type == DocumentType.medicalClearance &&
                e.$2.kind == DocumentExpiryKind.expired))
          e,
    ];
    if (docs.isNotEmpty) {
      final anyExpired = docs.any((e) => e.$2.kind == DocumentExpiryKind.expired);
      final single = docs.length == 1 ? docs.single : null;
      final label = single == null
          ? l10n.dashboard_gauges_documentsNeedAttention(docs.length)
          : single.$2.kind == DocumentExpiryKind.expired
          ? l10n.dashboard_gauges_documentExpired(
              documentDisplayTitle(l10n, single.$1),
            )
          : l10n.dashboard_gauges_documentExpires(
              documentDisplayTitle(l10n, single.$1),
              units.formatDate(single.$1.expiryDate),
            );
      chips.add(
        _chip(
          context,
          icon: Icons.folder_copy_outlined,
          label: label,
          tone: anyExpired || !docsShown ? _Tone.alert : _Tone.warn,
          onTap: () => context.push(
            single == null
                ? '/documents?filter=expiring'
                : '/documents/${single.$1.id}',
          ),
        ),
      );
    }
```

Home appearance: `HomeChipType.documents => l10n.settings_homeChips_documents,`.

- [ ] **Step 4: Run, expect PASS**

Run: `flutter test test/features/dashboard test/features/settings/presentation/pages/home_appearance_page_test.dart test/core/router`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dashboard lib/features/settings test/features/dashboard test/features/settings
git commit -m "feat(documents): documents home chip"
```

---

### Task 17: Expiry notifications

**Files:**
- Modify: `lib/core/services/notification_service.dart` (new `scheduleDocumentReminder`, `cancelDocumentReminders`)
- Modify: `lib/features/notifications/data/services/notification_scheduler.dart` (`scheduleAll` and new `_scheduleDocumentReminders`, `updateForDocument`, `cancelForDocument`)
- Modify: `lib/features/documents/presentation/providers/document_providers.dart` (`DocumentMutations._afterChange`)
- Test: `test/features/notifications/data/services/notification_scheduler_documents_test.dart`

**Interfaces:**
- Produces:
  - `NotificationService.scheduleDocumentReminder({required String documentId, required String title, required DocumentReminderStage stage, required int daysLeft, required DateTime scheduledDate})` returning `Future<int>`
  - `NotificationService.cancelDocumentReminders(String documentId)`
  - `enum DocumentReminderStage { lead, expiryDay }`
  - `List<({DocumentReminderStage stage, DateTime fireAt, int daysLeft})> documentReminderPlan(Document d, DateTime now, TimeOfDay at)` (pure, in `lib/features/documents/domain/document_reminder_plan.dart`)
  - `NotificationScheduler.updateForDocument(Document d, AppSettings settings)`, `cancelForDocument(String id)`

- [ ] **Step 1: Write the failing pure-plan test**

```dart
// test/features/documents/domain/document_reminder_plan_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_reminder_plan.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

Document d(DateTime? expiry, {int? lead, DocumentType t = DocumentType.permit}) =>
    Document(
      id: 'x',
      diverId: 'd',
      owner: const DocumentOwner.personal(),
      type: t,
      expiryDate: expiry,
      reminderLeadDays: lead,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  const at = TimeOfDay(hour: 9, minute: 0);
  final now = DateTime(2026, 10, 10, 12);

  test('lead day and expiry day at the reminder time', () {
    final plan = documentReminderPlan(d(DateTime(2026, 12, 31)), now, at);
    expect(plan.map((e) => e.fireAt), [
      DateTime(2026, 12, 1, 9),
      DateTime(2026, 12, 31, 9),
    ]);
    expect(plan.first.daysLeft, 30);
  });

  test('times already past are skipped', () {
    final plan = documentReminderPlan(d(DateTime(2026, 10, 20)), now, at);
    expect(plan.single.stage, DocumentReminderStage.expiryDay);
  });

  test('lead 0, no expiry, card type and expired plan nothing', () {
    expect(documentReminderPlan(d(DateTime(2027), lead: 0), now, at).length, 1);
    expect(documentReminderPlan(d(null), now, at), isEmpty);
    expect(
      documentReminderPlan(
        d(DateTime(2027), t: DocumentType.certificationCard),
        now,
        at,
      ),
      isEmpty,
    );
    expect(documentReminderPlan(d(DateTime(2026, 1, 1)), now, at), isEmpty);
  });
}
```

(`lead: 0` keeps only the expiry-day notification.)

- [ ] **Step 2: Run, expect FAIL; implement the plan**

```dart
// lib/features/documents/domain/document_reminder_plan.dart
import 'package:flutter/material.dart' show TimeOfDay;

import 'package:submersion/features/documents/domain/entities/document.dart';

enum DocumentReminderStage { lead, expiryDay }

typedef DocumentReminder = ({
  DocumentReminderStage stage,
  DateTime fireAt,
  int daysLeft,
});

/// When to remind about [document]: on the lead day and on the expiry day,
/// at the diver's reminder time, skipping any moment already past. Built
/// from calendar dates (`DateTime(y, m, d - n)`), so DST never moves a day.
List<DocumentReminder> documentReminderPlan(
  Document document,
  DateTime now,
  TimeOfDay at,
) {
  final expiry = document.expiryDate;
  if (!document.remindsOnExpiry || expiry == null) return const [];
  final lead = document.effectiveReminderLeadDays;
  final out = <DocumentReminder>[];
  if (lead > 0) {
    final fireAt = DateTime(
      expiry.year,
      expiry.month,
      expiry.day - lead,
      at.hour,
      at.minute,
    );
    if (fireAt.isAfter(now)) {
      out.add((stage: DocumentReminderStage.lead, fireAt: fireAt, daysLeft: lead));
    }
  }
  final expiryAt = DateTime(
    expiry.year,
    expiry.month,
    expiry.day,
    at.hour,
    at.minute,
  );
  if (expiryAt.isAfter(now)) {
    out.add((
      stage: DocumentReminderStage.expiryDay,
      fireAt: expiryAt,
      daysLeft: 0,
    ));
  }
  return out;
}
```

- [ ] **Step 3: Service methods** (mirroring `scheduleTripServiceReminder` at `notification_service.dart:228`)

```dart
  /// One-shot document expiry reminder (issue #2613). The id is stable per
  /// document and stage, so rescheduling replaces rather than duplicates.
  Future<int> scheduleDocumentReminder({
    required String documentId,
    required String title,
    required String body,
    required DocumentReminderStage stage,
    required DateTime scheduledDate,
  }) async {
    if (!_isMobilePlatform) return 0;
    final id = _stableNotificationId('document#$documentId#${stage.name}');
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: _documentDetails,
      payload: '/documents/$documentId',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return id;
  }

  Future<void> cancelDocumentReminders(String documentId) async {
    for (final stage in DocumentReminderStage.values) {
      await cancelNotification(
        _stableNotificationId('document#$documentId#${stage.name}'),
      );
    }
  }
```

`_documentDetails` follows the trip reminder's `NotificationDetails` with its own Android channel (`'document_expiry_reminders'`, name and description from l10n is not possible at this layer: use the same English constants pattern the existing channels use). Payload routing: follow how existing payloads are handled on tap; if payloads are not routed, pass `null` like the trip reminder.

Strings: the scheduler formats title and body from l10n (`notifications_document_expiresSoon_title/_body`, `_expiresToday_*`), using `lookupAppLocalizations(locale)` the way the existing scheduler builds its texts (check `_scheduleForClock`; mirror its source of strings).

- [ ] **Step 4: Scheduler**

In `scheduleAll`, after `_scheduleTripReminders`:

```dart
    await _scheduleDocumentReminders(settings: settings, diverId: diverId);
```

```dart
  Future<void> _scheduleDocumentReminders({
    required AppSettings settings,
    String? diverId,
  }) async {
    if (diverId == null) return;
    final documents = await _documentRepository.getRemindingForDiver(diverId);
    for (final document in documents) {
      await updateForDocument(document, settings);
    }
  }

  Future<void> updateForDocument(Document document, AppSettings settings) async {
    await _notificationService.cancelDocumentReminders(document.id);
    if (!settings.notificationsEnabled) return;
    for (final r in documentReminderPlan(
      document,
      DateTime.now(),
      settings.reminderTime,
    )) {
      await _notificationService.scheduleDocumentReminder(
        documentId: document.id,
        title: _documentReminderTitle(document, r),
        body: _documentReminderBody(r),
        stage: r.stage,
        scheduledDate: r.fireAt,
      );
    }
  }

  Future<void> cancelForDocument(String documentId) =>
      _notificationService.cancelDocumentReminders(documentId);
```

Add `DocumentRepository? documentRepository` to the constructor's optional injected dependencies (`:31-50`) as the others are.

`DocumentMutations._afterChange`:

```dart
  Future<void> _afterChange(Document? saved, {String? deletedId}) async {
    try {
      final scheduler = _ref.read(notificationSchedulerProvider);
      if (deletedId != null) {
        await scheduler.cancelForDocument(deletedId);
      } else if (saved != null) {
        await scheduler.updateForDocument(saved, _ref.read(settingsProvider));
      }
    } catch (e, st) {
      // A reminder failure never fails the save.
      LoggerService.forClass(DocumentMutations)
          .warning('Document reminder update failed', error: e, stackTrace: st);
    }
  }
```

- [ ] **Step 5: Scheduler test with a recording fake service**

```dart
// test/features/notifications/data/services/notification_scheduler_documents_test.dart
// Fake NotificationService records schedule/cancel calls. Seed one permit
// expiring in 60 days and one card document. scheduleAll(diverId: 'd1')
// schedules exactly two reminders for the permit and none for the card;
// updateForDocument after clearing the expiry cancels and schedules none;
// notificationsEnabled false schedules nothing.
```

Write it in full following the existing scheduler tests (`grep -rln "NotificationScheduler(" test/features/notifications`).

- [ ] **Step 6: Run, expect PASS; commit**

Run: `flutter test test/features/notifications test/features/documents`

```bash
git add lib/core/services/notification_service.dart lib/features/notifications lib/features/documents test/features/notifications test/features/documents
git commit -m "feat(documents): expiry notifications"
```

---

### Task 18: Full verification

- [ ] **Step 1: Format, analyze, guards**

Run: `dart format . && flutter analyze && flutter test test/architecture test/shared test/l10n`
Expected: no issues; no new file over 800 lines (`wc -l` the new files; split any that are).

- [ ] **Step 2: Affected suites**

Run: `flutter test test/features/documents test/features/divers test/features/certifications test/features/dashboard test/features/settings test/features/notifications test/core/database test/core/services/sync test/core/router test/shared/widgets/nav`
Expected: PASS. Log long runs to the scratchpad, not the worktree.

- [ ] **Step 3: Manual run**

Launch the app (the `run` skill), on macOS desktop and a phone-width window:
- Profile hub: insurance row summarises the migrated policy; Documents row counts personal docs.
- Add a personal permit with a PDF and a photo; reorder pages; view; open the PDF; delete a page.
- Add an insurance with front/back, mark primary; the emergency card shows it; the home insurance chip reads it.
- Trip, dive, site, equipment, course, cert, buddy, dive center pages each show the section; add a document from one and confirm the owner on the global page.
- A certification's edit page photos round-trip; the wallet shows them.
- Expired medical clearance shows the documents chip even when hidden.

- [ ] **Step 4: Commit any fixes**

```bash
git add <touched paths>
git commit -m "fix(documents): address verification findings"
```
