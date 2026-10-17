import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_owner_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_field.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<void> pumpField(WidgetTester t, DocumentOwner owner) async {
    final overrides = await getBaseOverrides();
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          documentOwnerLabelProvider.overrideWith(
            (ref, owner) async => switch (owner.id) {
              't1' => const DocumentOwnerOption('t1', 'Bonaire'),
              'c1' => const DocumentOwnerOption('c1', ''),
              _ => null,
            },
          ),
          documentOwnerCertificationProvider.overrideWith(
            (ref, id) async => switch (id) {
              'c1' => (name: '', agency: 'padi', level: 'advancedNitrox'),
              'c2' => (
                name: 'Adv. Nitrox',
                agency: 'padi',
                level: 'advancedNitrox',
              ),
              _ => null,
            },
          ),
        ],
        child: DocumentOwnerField(owner: owner, locked: false, onTap: () {}),
      ),
    );
    await t.pumpAndSettle();
  }

  // Issue #3366: a certification with no custom title stores an empty name,
  // and the field fell back to the bare word "Certification".
  testWidgets('a certification with no custom title shows its certification', (
    t,
  ) async {
    await pumpField(
      t,
      const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
    );
    expect(find.text('Advanced Nitrox'), findsOneWidget);
  });

  testWidgets('a certification with a custom title shows that title', (
    t,
  ) async {
    await pumpField(
      t,
      const DocumentOwner(DocumentOwnerKind.certification, 'c2'),
    );
    expect(find.text('Adv. Nitrox'), findsOneWidget);
  });

  testWidgets('another kind shows its record name', (t) async {
    await pumpField(t, const DocumentOwner(DocumentOwnerKind.trip, 't1'));
    expect(find.text('Bonaire'), findsOneWidget);
  });
}
