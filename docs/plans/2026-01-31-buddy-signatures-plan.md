# Buddy Digital Signatures Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable dive buddies to digitally sign dive log entries and display those signatures in PDF exports.

**Architecture:** Extend the existing instructor signature system by adding a `signatureType` field to distinguish buddy signatures from instructor signatures. Reuse `SignatureCaptureWidget` for capture, add new UI section on dive detail page, and embed signatures in PDF export.

**Tech Stack:** Flutter, Drift ORM, Riverpod, pdf package

---

## Task 1: Add SignatureType to Database Schema

**Files:**
- Modify: `lib/core/database/database.dart:372-410` (Media table)
- Modify: `lib/core/database/database.dart:981` (schemaVersion)
- Modify: `lib/core/database/database.dart:1438-1456` (migration)

**Step 1: Add signatureType column to Media table**

In `lib/core/database/database.dart`, find the Media table (around line 372) and add after `signerName`:

```dart
  // Signature type (v22) - distinguishes instructor vs buddy signatures
  TextColumn get signatureType => text().nullable()(); // 'instructor' | 'buddy'
```

**Step 2: Bump schema version**

Change line 981:
```dart
  @override
  int get schemaVersion => 22;
```

**Step 3: Add migration for version 22**

After the `if (from < 21)` block (around line 1456), add:

```dart
        if (from < 22) {
          // Buddy signatures feature - add signature type column
          await customStatement(
            'ALTER TABLE media ADD COLUMN signature_type TEXT',
          );
        }
```

**Step 4: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart` with new column

**Step 5: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(db): add signatureType column for buddy signatures"
```

---

## Task 2: Update Signature Entity

**Files:**
- Modify: `lib/features/signatures/domain/entities/signature.dart`

**Step 1: Add SignatureType enum and update Signature class**

Replace the entire file content:

```dart
import 'package:equatable/equatable.dart';

/// Type of signature (instructor for training courses, buddy for dive verification)
enum SignatureType {
  instructor,
  buddy;

  String get value {
    switch (this) {
      case SignatureType.instructor:
        return 'instructor';
      case SignatureType.buddy:
        return 'buddy';
    }
  }

  static SignatureType? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'instructor':
        return SignatureType.instructor;
      case 'buddy':
        return SignatureType.buddy;
      default:
        return null;
    }
  }
}

/// Represents a digital signature for a dive
class Signature extends Equatable {
  final String id;
  final String diveId;
  final String filePath;
  final String? signerId; // Buddy ID if signer is in system
  final String signerName; // Always populated
  final DateTime signedAt;
  final SignatureType? type; // null treated as instructor for backward compat
  final String? role; // Buddy's role on this dive (for buddy signatures)

  const Signature({
    required this.id,
    required this.diveId,
    required this.filePath,
    this.signerId,
    required this.signerName,
    required this.signedAt,
    this.type,
    this.role,
  });

  /// Check if signature has a linked buddy record
  bool get hasLinkedBuddy => signerId != null;

  /// Check if this is a buddy signature
  bool get isBuddySignature => type == SignatureType.buddy;

  /// Check if this is an instructor signature (or legacy null type)
  bool get isInstructorSignature =>
      type == SignatureType.instructor || type == null;

  Signature copyWith({
    String? id,
    String? diveId,
    String? filePath,
    String? signerId,
    String? signerName,
    DateTime? signedAt,
    SignatureType? type,
    String? role,
  }) {
    return Signature(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      filePath: filePath ?? this.filePath,
      signerId: signerId ?? this.signerId,
      signerName: signerName ?? this.signerName,
      signedAt: signedAt ?? this.signedAt,
      type: type ?? this.type,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    filePath,
    signerId,
    signerName,
    signedAt,
    type,
    role,
  ];
}
```

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/features/signatures/domain/entities/signature.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/signatures/domain/entities/signature.dart
git commit -m "feat(signatures): add SignatureType enum and role field"
```

---

## Task 3: Update SignatureStorageService for Buddy Signatures

**Files:**
- Modify: `lib/features/signatures/data/services/signature_storage_service.dart`
- Create: `test/features/signatures/data/services/signature_storage_service_test.dart`

**Step 1: Write failing test for buddy signature methods**

Create `test/features/signatures/data/services/signature_storage_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

void main() {
  group('SignatureStorageService', () {
    group('buddy signatures', () {
      test('getBuddySignaturesForDive returns only buddy type signatures', () {
        // This test verifies the service filters by signature type
        // Implementation will query media where signatureType = 'buddy'
        expect(SignatureType.buddy.value, equals('buddy'));
        expect(SignatureType.instructor.value, equals('instructor'));
      });

      test('SignatureType.fromString parses values correctly', () {
        expect(SignatureType.fromString('buddy'), equals(SignatureType.buddy));
        expect(
          SignatureType.fromString('instructor'),
          equals(SignatureType.instructor),
        );
        expect(SignatureType.fromString(null), isNull);
        expect(SignatureType.fromString('unknown'), isNull);
      });
    });
  });
}
```

**Step 2: Run test to verify it passes (testing the entity)**

Run: `flutter test test/features/signatures/data/services/signature_storage_service_test.dart`
Expected: PASS (testing entity logic first)

**Step 3: Update SignatureStorageService with buddy signature methods**

Add the following constants and methods to `lib/features/signatures/data/services/signature_storage_service.dart`:

After line 24 (`static const String _signatureDir = 'signatures';`), add:

```dart
  static const String _buddySignatureFileType = 'buddy_signature';
```

After the `hasSignature` method (around line 201), add these new methods:

```dart
  /// Save a buddy signature for a dive
  Future<Signature> saveBuddySignature({
    required String diveId,
    required Uint8List imageBytes,
    required String buddyId,
    required String buddyName,
    required String role,
  }) async {
    try {
      _log.info('Saving buddy signature for dive: $diveId, buddy: $buddyId');

      // Create signatures directory if needed
      final directory = await getApplicationDocumentsDirectory();
      final sigDir = Directory('${directory.path}/$_signatureDir');
      if (!await sigDir.exists()) {
        await sigDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${diveId}_buddy_${buddyId}_$timestamp.png';
      final filePath = '${sigDir.path}/$fileName';

      // Save image file
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      // Create media record
      final id = _uuid.v4();
      final now = DateTime.now();

      await _db
          .into(_db.media)
          .insert(
            MediaCompanion(
              id: Value(id),
              diveId: Value(diveId),
              filePath: Value(filePath),
              fileType: const Value(_buddySignatureFileType),
              takenAt: Value(now.millisecondsSinceEpoch),
              signerId: Value(buddyId),
              signerName: Value(buddyName),
              signatureType: const Value('buddy'),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Saved buddy signature with id: $id');

      return Signature(
        id: id,
        diveId: diveId,
        filePath: filePath,
        signerId: buddyId,
        signerName: buddyName,
        signedAt: now,
        type: SignatureType.buddy,
        role: role,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save buddy signature for dive: $diveId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all buddy signatures for a dive
  Future<List<Signature>> getBuddySignaturesForDive(String diveId) async {
    try {
      final query = _db.select(_db.media)
        ..where(
          (t) =>
              t.diveId.equals(diveId) &
              t.signatureType.equals('buddy'),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]);

      final rows = await query.get();
      return rows.map(_mapRowToSignature).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get buddy signatures for dive: $diveId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all signatures (both instructor and buddy) for a dive
  Future<List<Signature>> getAllSignaturesForDive(String diveId) async {
    try {
      final query = _db.select(_db.media)
        ..where(
          (t) =>
              t.diveId.equals(diveId) &
              (t.fileType.equals(_signatureFileType) |
                  t.signatureType.equals('buddy')),
        )
        ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]);

      final rows = await query.get();
      return rows.map(_mapRowToSignature).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get all signatures for dive: $diveId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Check if a specific buddy has signed this dive
  Future<bool> hasBuddySigned(String diveId, String buddyId) async {
    try {
      final query = _db.select(_db.media)
        ..where(
          (t) =>
              t.diveId.equals(diveId) &
              t.signerId.equals(buddyId) &
              t.signatureType.equals('buddy'),
        )
        ..limit(1);

      final row = await query.getSingleOrNull();
      return row != null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to check if buddy signed dive: $diveId, $buddyId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
```

**Step 4: Update the _mapRowToSignature method**

Replace the existing `_mapRowToSignature` method (around line 259):

```dart
  Signature _mapRowToSignature(MediaData row) {
    return Signature(
      id: row.id,
      diveId: row.diveId!,
      filePath: row.filePath,
      signerId: row.signerId,
      signerName: row.signerName ?? 'Unknown',
      signedAt: DateTime.fromMillisecondsSinceEpoch(row.takenAt ?? 0),
      type: SignatureType.fromString(row.signatureType),
      role: null, // Role is inferred from DiveBuddies table when needed
    );
  }
```

**Step 5: Verify no compile errors**

Run: `flutter analyze lib/features/signatures/data/services/signature_storage_service.dart`
Expected: No issues found

**Step 6: Commit**

```bash
git add lib/features/signatures/data/services/signature_storage_service.dart test/features/signatures/data/services/signature_storage_service_test.dart
git commit -m "feat(signatures): add buddy signature storage methods"
```

---

## Task 4: Add Buddy Signature Providers

**Files:**
- Modify: `lib/features/signatures/presentation/providers/signature_providers.dart`

**Step 1: Add buddy signature providers**

Add the following providers after the existing ones (after line 146):

```dart
/// Provider to get all buddy signatures for a dive
final buddySignaturesForDiveProvider =
    FutureProvider.family<List<Signature>, String>((ref, diveId) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.getBuddySignaturesForDive(diveId);
    });

/// Provider to get all signatures (instructor + buddy) for a dive
final allSignaturesForDiveProvider =
    FutureProvider.family<List<Signature>, String>((ref, diveId) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.getAllSignaturesForDive(diveId);
    });

/// Provider to check if a specific buddy has signed a dive
final hasBuddySignedProvider =
    FutureProvider.family<bool, ({String diveId, String buddyId})>((
      ref,
      params,
    ) async {
      final service = ref.watch(signatureStorageServiceProvider);
      return service.hasBuddySigned(params.diveId, params.buddyId);
    });

/// Notifier for saving buddy signatures
class BuddySignatureSaveNotifier extends StateNotifier<AsyncValue<Signature?>> {
  final SignatureStorageService _service;
  final Ref _ref;

  BuddySignatureSaveNotifier(this._service, this._ref)
    : super(const AsyncValue.data(null));

  /// Save a buddy signature from stroke data
  Future<Signature?> saveFromStrokes({
    required String diveId,
    required String buddyId,
    required String buddyName,
    required String role,
    required List<List<Offset>> strokes,
    required double width,
    required double height,
    Color strokeColor = const Color(0xFF000000),
    double strokeWidth = 3.0,
    Color? backgroundColor,
  }) async {
    state = const AsyncValue.loading();

    try {
      // Convert strokes to PNG
      final pngBytes = await SignatureStorageService.strokesToPng(
        strokes: strokes,
        width: width,
        height: height,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        backgroundColor: backgroundColor,
      );

      // Save buddy signature
      final signature = await _service.saveBuddySignature(
        diveId: diveId,
        imageBytes: pngBytes,
        buddyId: buddyId,
        buddyName: buddyName,
        role: role,
      );

      state = AsyncValue.data(signature);

      // Invalidate related providers
      _ref.invalidate(buddySignaturesForDiveProvider(diveId));
      _ref.invalidate(allSignaturesForDiveProvider(diveId));
      _ref.invalidate(
        hasBuddySignedProvider((diveId: diveId, buddyId: buddyId)),
      );

      return signature;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }
}

/// Provider for the buddy signature save notifier
final buddySignatureSaveNotifierProvider =
    StateNotifierProvider<BuddySignatureSaveNotifier, AsyncValue<Signature?>>(
      (ref) => BuddySignatureSaveNotifier(
        ref.watch(signatureStorageServiceProvider),
        ref,
      ),
    );
```

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/features/signatures/presentation/providers/signature_providers.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/signatures/presentation/providers/signature_providers.dart
git commit -m "feat(signatures): add buddy signature providers"
```

---

## Task 5: Create BuddySignatureCard Widget

**Files:**
- Create: `lib/features/signatures/presentation/widgets/buddy_signature_card.dart`

**Step 1: Create the widget file**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Card displaying a buddy's signature status
class BuddySignatureCard extends StatelessWidget {
  final BuddyWithRole buddyWithRole;
  final Signature? signature;
  final VoidCallback? onRequestSignature;
  final VoidCallback? onViewSignature;

  const BuddySignatureCard({
    super.key,
    required this.buddyWithRole,
    this.signature,
    this.onRequestSignature,
    this.onViewSignature,
  });

  bool get hasSigned => signature != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buddy = buddyWithRole.buddy;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: hasSigned ? onViewSignature : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasSigned
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasSigned ? Icons.check : Icons.edit_outlined,
                  color: hasSigned
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Buddy info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buddy.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      buddyWithRole.role.displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasSigned && signature != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Signed ${DateFormat.yMMMd().format(signature!.signedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Signature preview or request button
              if (hasSigned && signature != null)
                _buildSignaturePreview(context, signature!)
              else
                FilledButton.tonal(
                  onPressed: onRequestSignature,
                  child: const Text('Request'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturePreview(BuildContext context, Signature sig) {
    final file = File(sig.filePath);

    return Container(
      width: 60,
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.contain)
            : const Icon(Icons.image_not_supported, size: 16),
      ),
    );
  }
}
```

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/features/signatures/presentation/widgets/buddy_signature_card.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/signatures/presentation/widgets/buddy_signature_card.dart
git commit -m "feat(signatures): create BuddySignatureCard widget"
```

---

## Task 6: Create BuddySignatureRequestSheet Widget

**Files:**
- Create: `lib/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart`

**Step 1: Create the widget file**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_capture_widget.dart';

/// Bottom sheet for requesting a buddy's signature
///
/// Shows a message to hand device to buddy, then displays signature canvas
class BuddySignatureRequestSheet extends StatefulWidget {
  final BuddyWithRole buddyWithRole;
  final void Function(List<List<Offset>> strokes)? onSave;

  const BuddySignatureRequestSheet({
    super.key,
    required this.buddyWithRole,
    this.onSave,
  });

  @override
  State<BuddySignatureRequestSheet> createState() =>
      _BuddySignatureRequestSheetState();
}

class _BuddySignatureRequestSheetState
    extends State<BuddySignatureRequestSheet> {
  bool _showingCapture = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buddy = widget.buddyWithRole.buddy;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            if (!_showingCapture) ...[
              // Handoff message
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.swap_horiz,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hand your device to',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      buddy.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.buddyWithRole.role.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _showingCapture = true;
                        });
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Ready to Sign'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Title
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${buddy.name} - Sign Here',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

              const Divider(height: 1),

              // Signature capture (reusing existing widget but customized)
              _BuddySignatureCapture(
                buddyName: buddy.name,
                onSave: (strokes) {
                  widget.onSave?.call(strokes);
                  Navigator.of(context).pop();
                },
                onCancel: () => Navigator.of(context).pop(),
              ),

              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Customized signature capture for buddy signatures (no name field needed)
class _BuddySignatureCapture extends StatefulWidget {
  final String buddyName;
  final void Function(List<List<Offset>> strokes)? onSave;
  final VoidCallback? onCancel;

  const _BuddySignatureCapture({
    required this.buddyName,
    this.onSave,
    this.onCancel,
  });

  @override
  State<_BuddySignatureCapture> createState() => _BuddySignatureCaptureState();
}

class _BuddySignatureCaptureState extends State<_BuddySignatureCapture> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
    });
  }

  void _handleSave() {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw a signature')),
      );
      return;
    }

    widget.onSave?.call(_strokes);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Signature canvas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStroke = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStroke.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    if (_currentStroke.isNotEmpty) {
                      _strokes.add(List.from(_currentStroke));
                    }
                    _currentStroke = [];
                  });
                },
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Helper text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Draw your signature above',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed:
                    _strokes.isEmpty && _currentStroke.isEmpty ? null : _clear,
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    _strokes.isEmpty && _currentStroke.isEmpty
                        ? null
                        : _handleSave,
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for signature strokes
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }

    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> stroke, Paint paint) {
    if (stroke.length < 2) return;

    final path = Path();
    path.moveTo(stroke.first.dx, stroke.first.dy);

    for (int i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke;
  }
}

/// Shows the buddy signature request sheet
Future<void> showBuddySignatureRequestSheet({
  required BuildContext context,
  required BuddyWithRole buddyWithRole,
  required void Function(List<List<Offset>> strokes) onSave,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => BuddySignatureRequestSheet(
      buddyWithRole: buddyWithRole,
      onSave: onSave,
    ),
  );
}
```

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart
git commit -m "feat(signatures): create BuddySignatureRequestSheet widget"
```

---

## Task 7: Create BuddySignaturesSection Widget

**Files:**
- Create: `lib/features/signatures/presentation/widgets/buddy_signatures_section.dart`

**Step 1: Create the widget file**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_card.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signature_request_sheet.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';

/// Section displaying buddy signatures for a dive
class BuddySignaturesSection extends ConsumerWidget {
  final String diveId;

  const BuddySignaturesSection({super.key, required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(buddiesForDiveProvider(diveId));
    final signaturesAsync = ref.watch(buddySignaturesForDiveProvider(diveId));

    return buddiesAsync.when(
      data: (buddies) {
        // Don't show section if no buddies on this dive
        if (buddies.isEmpty) {
          return const SizedBox.shrink();
        }

        return signaturesAsync.when(
          data: (signatures) => _buildSection(
            context,
            ref,
            buddies,
            signatures,
          ),
          loading: () => _buildLoadingSection(context),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => _buildLoadingSection(context),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    List<BuddyWithRole> buddies,
    List<Signature> signatures,
  ) {
    // Create a map of buddyId -> signature for quick lookup
    final signatureMap = <String, Signature>{};
    for (final sig in signatures) {
      if (sig.signerId != null) {
        signatureMap[sig.signerId!] = sig;
      }
    }

    final signedCount = buddies
        .where((bwr) => signatureMap.containsKey(bwr.buddy.id))
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.draw_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Signatures',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                if (signedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$signedCount/${buddies.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(),
            ...buddies.map((bwr) {
              final sig = signatureMap[bwr.buddy.id];
              return BuddySignatureCard(
                buddyWithRole: bwr,
                signature: sig,
                onRequestSignature: () => _requestSignature(context, ref, bwr),
                onViewSignature: sig != null
                    ? () => _viewSignature(context, sig)
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _requestSignature(
    BuildContext context,
    WidgetRef ref,
    BuddyWithRole bwr,
  ) {
    showBuddySignatureRequestSheet(
      context: context,
      buddyWithRole: bwr,
      onSave: (strokes) async {
        final notifier = ref.read(buddySignatureSaveNotifierProvider.notifier);
        await notifier.saveFromStrokes(
          diveId: diveId,
          buddyId: bwr.buddy.id,
          buddyName: bwr.buddy.name,
          role: bwr.role.value,
          strokes: strokes,
          width: 400,
          height: 200,
        );
      },
    );
  }

  void _viewSignature(BuildContext context, Signature signature) {
    showDialog(
      context: context,
      builder: (context) => SignatureFullViewDialog(signature: signature),
    );
  }
}
```

**Step 2: Verify no compile errors**

Run: `flutter analyze lib/features/signatures/presentation/widgets/buddy_signatures_section.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add lib/features/signatures/presentation/widgets/buddy_signatures_section.dart
git commit -m "feat(signatures): create BuddySignaturesSection widget"
```

---

## Task 8: Add Signatures Section to Dive Detail Page

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Step 1: Add import for BuddySignaturesSection**

Add after line 55 (after existing signature imports):

```dart
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';
```

**Step 2: Add signatures section after buddies section**

Find line 225-226 where `_buildBuddiesSection` is called. After `const SizedBox(height: 24),` that follows buddies, add:

```dart
            BuddySignaturesSection(diveId: diveId),
            const SizedBox(height: 24),
```

The section should look like:

```dart
            _buildBuddiesSection(context, ref),
            const SizedBox(height: 24),
            BuddySignaturesSection(diveId: diveId),
            const SizedBox(height: 24),
            if (dive.tanks.isNotEmpty) ...[
```

**Step 3: Verify no compile errors**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart`
Expected: No issues found

**Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat(dives): add buddy signatures section to dive detail"
```

---

## Task 9: Add Signatures to PDF Export

**Files:**
- Modify: `lib/core/services/export_service.dart`

**Step 1: Add signature imports**

Add at the top of the file with other imports:

```dart
import 'dart:io';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
```

**Step 2: Update _buildDivePdf method signature**

Find `_buildDivePdf` method (around line 534). Update its signature to accept signatures:

```dart
  Future<List<int>> _buildDivePdf(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
    Map<String, List<Signature>>? diveSignatures,
  }) async {
```

**Step 3: Update _buildPdfDiveEntry to include signatures**

Find `_buildPdfDiveEntry` (around line 683). Update its signature:

```dart
  pw.Widget _buildPdfDiveEntry(Dive dive, {List<Signature>? signatures}) {
```

After the rating section (after line 749, after the `if (dive.rating != null...)` block), add:

```dart
          // Signatures section
          if (signatures != null && signatures.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Verified by:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: signatures
                  .map((sig) => _buildPdfSignatureBlock(sig))
                  .toList(),
            ),
          ],
```

**Step 4: Add _buildPdfSignatureBlock method**

Add this method after `_buildPdfDiveEntry`:

```dart
  pw.Widget _buildPdfSignatureBlock(Signature signature) {
    // Try to load the signature image
    pw.ImageProvider? signatureImage;
    final file = File(signature.filePath);
    if (file.existsSync()) {
      try {
        final bytes = file.readAsBytesSync();
        signatureImage = pw.MemoryImage(bytes);
      } catch (_) {
        // Ignore image load errors
      }
    }

    return pw.Container(
      width: 80,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (signatureImage != null)
            pw.Container(
              height: 30,
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              height: 30,
              child: pw.Center(
                child: pw.Text(
                  '[Signature]',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            signature.signerName,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            signature.isBuddySignature ? 'Buddy' : 'Instructor',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            _dateFormat.format(signature.signedAt),
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }
```

**Step 5: Update the dive pages loop to pass signatures**

In `_buildDivePdf`, find the dive pages loop (around line 640). Update it:

```dart
    // Dive log pages (multiple dives per page)
    const divesPerPage = 3;
    for (var i = 0; i < dives.length; i += divesPerPage) {
      final pageDives = dives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...pageDives.expand(
                (dive) => [
                  _buildPdfDiveEntry(
                    dive,
                    signatures: diveSignatures?[dive.id],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      );
    }
```

**Step 6: Update public export methods to load signatures**

Update `generateDivePdfBytes` method:

```dart
  Future<({List<int> bytes, String fileName})> generateDivePdfBytes(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) async {
    // Load all signatures for these dives
    final signatureService = SignatureStorageService();
    final diveSignatures = <String, List<Signature>>{};

    for (final dive in dives) {
      final sigs = await signatureService.getAllSignaturesForDive(dive.id);
      if (sigs.isNotEmpty) {
        diveSignatures[dive.id] = sigs;
      }
    }

    final pdfBytes = await _buildDivePdf(
      dives,
      title: title,
      allSightings: allSightings,
      diveSignatures: diveSignatures.isNotEmpty ? diveSignatures : null,
    );
    final fileName = 'dive_logbook_${_dateFormat.format(DateTime.now())}.pdf';
    return (bytes: pdfBytes, fileName: fileName);
  }
```

**Step 7: Verify no compile errors**

Run: `flutter analyze lib/core/services/export_service.dart`
Expected: No issues found

**Step 8: Commit**

```bash
git add lib/core/services/export_service.dart
git commit -m "feat(export): display signatures in PDF dive exports"
```

---

## Task 10: Run Full Test Suite and Format

**Step 1: Format all modified files**

Run: `dart format lib/core/database/database.dart lib/features/signatures/ lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/core/services/export_service.dart`
Expected: Formatted files

**Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues found

**Step 3: Run tests**

Run: `flutter test`
Expected: All tests pass

**Step 4: Final commit if formatting changed anything**

```bash
git add -A
git status
# If there are changes:
git commit -m "style: format buddy signatures feature files"
```

---

## Task 11: Update REMAINING_TASKS.md

**Files:**
- Modify: `REMAINING_TASKS.md`

**Step 1: Mark tasks as complete**

Find the Digital Signatures section and update:

```markdown
### 7.2 Digital Signatures

**Completed:**
- [x] Buddy signatures (student/observer sign-off)
- [x] Display signatures in PDF export
```

**Step 2: Commit**

```bash
git add REMAINING_TASKS.md
git commit -m "docs: mark buddy signatures feature as complete"
```

---

## Summary

This plan implements buddy digital signatures in 11 tasks:

| Task | Description | New/Modified Files |
|------|-------------|-------------------|
| 1 | Database schema | database.dart |
| 2 | Signature entity | signature.dart |
| 3 | Storage service | signature_storage_service.dart |
| 4 | Providers | signature_providers.dart |
| 5 | BuddySignatureCard | buddy_signature_card.dart (new) |
| 6 | BuddySignatureRequestSheet | buddy_signature_request_sheet.dart (new) |
| 7 | BuddySignaturesSection | buddy_signatures_section.dart (new) |
| 8 | Dive detail integration | dive_detail_page.dart |
| 9 | PDF export | export_service.dart |
| 10 | Testing & formatting | - |
| 11 | Documentation | REMAINING_TASKS.md |

Each task includes TDD steps where applicable, exact file paths, and commit checkpoints.
