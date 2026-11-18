import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/features/signatures/presentation/widgets/buddy_signatures_section.dart';

import '../../../../helpers/test_app.dart';

/// Once a buddy's signature exists, the card shows it instead of the
/// "Request" button (issue #1358). A signature drawn here is handed to
/// `onCaptured`, which holds it in the open card's sitting until Save (issue
/// #4527); without it no buddy is asked to sign.
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
    void Function(BuddyWithRole bwr, List<List<Offset>> strokes, Size size)?
    onCaptured,
  }) async {
    await tester.pumpWidget(
      testApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        overrides: [
          buddiesForDiveProvider.overrideWith(
            (ref, id) async => [
              BuddyWithRole(buddy: buddy, roles: [DiveRole.builtInBuddy()]),
            ],
          ),
          buddySignaturesForDiveProvider.overrideWith(
            (ref, id) async => signatures,
          ),
        ],
        child: BuddySignaturesSection(diveId: diveId, onCaptured: onCaptured),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers Request while the buddy has not signed', (tester) async {
    await pumpSection(tester, signatures: const [], onCaptured: (_, _, _) {});

    expect(find.text('Request'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('with nowhere to hold a signature, Request is not offered', (
    tester,
  ) async {
    await pumpSection(tester, signatures: const []);

    // Hidden, it keeps its room so the card does not change height.
    final request = find.ancestor(
      of: find.text('Request'),
      matching: find.byType(Visibility),
    );
    expect(tester.widget<Visibility>(request).visible, isFalse);
  });

  testWidgets('a drawn signature is handed over, not saved', (tester) async {
    final captured = <String>[];
    await pumpSection(
      tester,
      signatures: const [],
      onCaptured: (bwr, strokes, _) {
        if (strokes.isNotEmpty) captured.add(bwr.buddy.id);
      },
    );

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

    expect(captured, [buddyId]);
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
