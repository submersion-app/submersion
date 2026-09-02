import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';

import '../../../helpers/test_app.dart';

BuddyWithDiveCount _entry() => BuddyWithDiveCount(
  buddy: Buddy(
    id: 'b1',
    name: 'Jane Doe',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  diveCount: 3,
);

Widget _table({Widget Function(BuddyWithDiveCount entity)? leadingBuilder}) {
  return EntityTableView<BuddyWithDiveCount, BuddyField>(
    entities: [_entry()],
    idExtractor: (e) => e.buddy.id,
    adapter: BuddyFieldAdapter.instance,
    config: EntityTableViewConfig<BuddyField>(
      columns: [EntityTableColumnConfig(field: BuddyField.buddyName)],
    ),
    units: const UnitFormatter(AppSettings()),
    onSortFieldChanged: (_) {},
    onResizeColumn: (_, _) {},
    onEntityTap: (_) {},
    leadingBuilder: leadingBuilder,
  );
}

void main() {
  testWidgets('renders no leading widget when leadingBuilder is null', (
    tester,
  ) async {
    await tester.pumpWidget(testApp(child: _table()));
    await tester.pump();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byKey(const ValueKey('lead')), findsNothing);
  });

  testWidgets('renders one leading widget per row when given a builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: _table(
          leadingBuilder: (_) =>
              const Icon(Icons.person, key: ValueKey('lead')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byKey(const ValueKey('lead')), findsOneWidget);
  });
}
