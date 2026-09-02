import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';

import '../../../../helpers/test_app.dart';

/// The display half of issue #1358: once a buddy's signature exists, the card
/// has to show it instead of the "Request" button.
///
/// The save half is covered in buddy_signature_save_notifier_test.dart, which
/// runs the real notifier against a real database. It cannot live here: the
/// save finishes through `Picture.toImage`, whose future the engine completes
/// rather than a timer, so it never resumes under a widget test's fake clock.
void main() {
  const diveId = 'dive-1';
  const buddyId = 'buddy-1';

  final buddy = Buddy(
    id: buddyId,
    name: 'Reef Buddy',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  /// A 1x1 transparent PNG -- real bytes, so Image.memory decodes them.
  final pngBytes = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  Future<void> pumpSection(
    WidgetTester tester, {
    required List<Signature> signatures,
  }) async {
    await tester.pumpWidget(
      testApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        overrides: [
          buddiesForDiveProvider.overrideWith(
            (ref, id) async => [
              BuddyWithRole(buddy: buddy, role: DiveRole.builtInBuddy()),
            ],
          ),
          buddySignaturesForDiveProvider.overrideWith(
            (ref, id) async => signatures,
          ),
        ],
        child: const BuddySignaturesSection(diveId: diveId),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers Request while the buddy has not signed', (tester) async {
    await pumpSection(tester, signatures: const []);

    expect(find.text('Request'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  /// Drives Request -> Ready to Sign -> draw -> Done with [saveResult] as the
  /// notifier's answer. The notifier is faked so the flow never reaches
  /// `strokesToPng`, which would hang here; what is under test is how the
  /// section reacts to the answer, not the encode.
  Future<void> signWithResult(
    WidgetTester tester,
    Signature? saveResult,
  ) async {
    await tester.pumpWidget(
      testApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        overrides: [
          buddiesForDiveProvider.overrideWith(
            (ref, id) async => [
              BuddyWithRole(buddy: buddy, role: DiveRole.builtInBuddy()),
            ],
          ),
          buddySignaturesForDiveProvider.overrideWith((ref, id) async => []),
          buddySignatureSaveNotifierProvider.overrideWith(
            (ref) => _FakeSaveNotifier(ref, saveResult),
          ),
        ],
        child: const BuddySignaturesSection(diveId: diveId),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready to Sign'));
    await tester.pumpAndSettle();

    final origin = tester.getCenter(find.bySemanticsLabel('Draw signature'));
    final gesture = await tester.startGesture(origin - const Offset(60, 20));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(15, 5));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed save tells the diver instead of failing silently', (
    tester,
  ) async {
    // The #1358 symptom exactly: the save threw, the notifier swallowed it
    // into an AsyncValue nothing watches, and the diver saw an unchanged
    // Request button with no explanation.
    await signWithResult(tester, null);

    expect(
      find.text('Could not save the signature. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a successful save says nothing', (tester) async {
    await signWithResult(
      tester,
      Signature(
        id: 'sig-1',
        diveId: diveId,
        imageData: pngBytes,
        signerId: buddyId,
        signerName: buddy.name,
        signedAt: DateTime.utc(2026, 1, 2),
        type: SignatureType.buddy,
      ),
    );

    expect(
      find.text('Could not save the signature. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('shows the signature instead of Request once signed', (
    tester,
  ) async {
    await pumpSection(
      tester,
      signatures: [
        Signature(
          id: 'sig-1',
          diveId: diveId,
          imageData: pngBytes,
          signerId: buddyId,
          signerName: buddy.name,
          signedAt: DateTime.utc(2026, 1, 2),
          type: SignatureType.buddy,
        ),
      ],
    );

    expect(find.text('Request'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    // The header counter proves the signature was matched to this buddy by
    // signerId rather than merely rendered somewhere on the card.
    expect(find.text('1/1'), findsOneWidget);
  });
}

/// Answers [_result] without touching the encoder or the database, so the
/// section's reaction to a save can be tested on its own.
class _FakeSaveNotifier extends BuddySignatureSaveNotifier {
  _FakeSaveNotifier(Ref ref, this._result)
    : super(SignatureStorageService(), ref);

  final Signature? _result;

  @override
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
  }) async => _result;
}
