import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/widgets/signature_display_widget.dart';

import '../../../../helpers/test_app.dart';

/// Issue #3034: a buddy's saved signature was titled "Instructor Signature"
/// because both the card and the full view hardcoded that heading.
void main() {
  Signature signatureOfType(SignatureType? type) => Signature(
    id: 'sig-1',
    diveId: 'dive-1',
    signerName: 'Reef Buddy',
    signedAt: DateTime.utc(2026, 10, 5, 13, 19),
    type: type,
  );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      testApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        child: Material(child: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SignatureFullViewDialog', () {
    testWidgets('titles a buddy signature as a buddy signature', (
      tester,
    ) async {
      await pump(
        tester,
        SignatureFullViewDialog(
          signature: signatureOfType(SignatureType.buddy),
        ),
      );

      expect(find.text('Buddy Signature'), findsOneWidget);
      expect(find.text('Instructor Signature'), findsNothing);
    });

    testWidgets('titles an instructor signature as an instructor signature', (
      tester,
    ) async {
      await pump(
        tester,
        SignatureFullViewDialog(
          signature: signatureOfType(SignatureType.instructor),
        ),
      );

      expect(find.text('Instructor Signature'), findsOneWidget);
      expect(find.text('Buddy Signature'), findsNothing);
    });

    testWidgets('treats a legacy untyped signature as an instructor one', (
      tester,
    ) async {
      await pump(
        tester,
        SignatureFullViewDialog(signature: signatureOfType(null)),
      );

      expect(find.text('Instructor Signature'), findsOneWidget);
    });
  });

  group('SignatureDisplayWidget', () {
    testWidgets('titles a buddy signature as a buddy signature', (
      tester,
    ) async {
      await pump(
        tester,
        SignatureDisplayWidget(signature: signatureOfType(SignatureType.buddy)),
      );

      expect(find.text('Buddy Signature'), findsOneWidget);
      expect(find.text('Instructor Signature'), findsNothing);
    });

    testWidgets('titles an instructor signature as an instructor signature', (
      tester,
    ) async {
      await pump(
        tester,
        SignatureDisplayWidget(
          signature: signatureOfType(SignatureType.instructor),
        ),
      );

      expect(find.text('Instructor Signature'), findsOneWidget);
    });
  });
}
