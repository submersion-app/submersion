import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

  Future<ProviderContainer> pumpRouted(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        tagsForEquipmentProvider(
          'e1',
        ).overrideWith((ref) async => [rental, travel]),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/equipment/e1',
      routes: [
        GoRoute(
          path: '/equipment',
          builder: (_, _) => const Scaffold(body: Text('EQUIPMENT_LIST')),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, _) =>
              const Scaffold(body: EquipmentTagChips(equipmentId: 'e1')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('tapping a chip opens the list filtered to that tag alone', (
    tester,
  ) async {
    final container = await pumpRouted(tester);
    // A leftover category would hide some of the tag's items.
    container.read(equipmentFilterProvider.notifier).state =
        const EquipmentFilterState(type: EquipmentType.regulator);

    await tester.tap(find.text('Travel kit'));
    await tester.pumpAndSettle();

    expect(find.text('EQUIPMENT_LIST'), findsOneWidget);
    expect(
      container.read(equipmentFilterProvider),
      const EquipmentFilterState(tagIds: {'t1'}),
    );
  });

  testWidgets('each chip says what a tap does', (tester) async {
    await pumpRouted(tester);

    expect(find.byTooltip('Show equipment with Travel kit'), findsOneWidget);
    expect(find.byTooltip('Show equipment with Rental'), findsOneWidget);
  });
}
