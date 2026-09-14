import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_app.dart';

/// The tag chip row on equipment detail (issue #1942).
void main() {
  final now = DateTime(2026);
  Tag tag(String id, String name) => Tag(
    id: id,
    name: name,
    colorHex: '#4CAF50',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final travel = tag('t1', 'Travel kit');
  final rental = tag('t2', 'Rental');

  Widget wrap(List<Tag> tags) => testApp(
    locale: const Locale('en'),
    overrides: [
      tagsForEquipmentProvider('e1').overrideWith((ref) async => tags),
    ],
    child: const EquipmentTagChips(equipmentId: 'e1'),
  );

  testWidgets('shows a chip per tag', (tester) async {
    await tester.pumpWidget(wrap([rental, travel]));
    await tester.pumpAndSettle();

    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Travel kit'), findsOneWidget);
  });

  testWidgets('renders nothing for an item without tags', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byType(Wrap), findsNothing);
  });
}
