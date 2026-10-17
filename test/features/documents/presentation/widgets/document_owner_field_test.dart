import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/documents/data/repositories/document_owner_options_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/dive_owner_label.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_owner_providers.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_owner_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _date = DateTime.utc(2026, 10, 12, 9);

class _FakeOptions extends DocumentOwnerOptionsRepository {
  @override
  Future<DiveOwnerLabel?> diveLabel(String diveId) async =>
      DiveOwnerLabel(number: 142, siteName: 'Blue Hole', date: _date);
}

Document _doc(DocumentOwner owner) => Document(
  id: 'x',
  diverId: 'd1',
  owner: owner,
  type: DocumentType.booking,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('a dive reads as number, site and date (#3391)', (t) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          documentOwnerOptionsRepositoryProvider.overrideWithValue(
            _FakeOptions(),
          ),
        ],
        child: DocumentOwnerField(
          owner: const DocumentOwner(DocumentOwnerKind.dive, 'v1'),
          locked: false,
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    final date = const UnitFormatter(AppSettings()).formatDate(_date);
    expect(find.text('#142 · Blue Hole · $date'), findsOneWidget);
  });

  test('resolveDiveOwnerLabels formats dives and leaves other owners', () {
    final entries = [
      DocumentListEntry(
        _doc(const DocumentOwner(DocumentOwnerKind.dive, 'v1')),
        null,
        1,
        dive: DiveOwnerLabel(number: 142, siteName: 'Blue Hole', date: _date),
      ),
      DocumentListEntry(
        _doc(const DocumentOwner(DocumentOwnerKind.trip, 't1')),
        'Bonaire',
        1,
      ),
    ];
    final resolved = resolveDiveOwnerLabels(entries, (d) => 'D${d.day}');
    expect(resolved.map((e) => e.ownerLabel), [
      '#142 · Blue Hole · D12',
      'Bonaire',
    ]);
  });
}
