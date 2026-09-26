import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';
import 'package:submersion/features/equipment/domain/services/equipment_history_builder.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_history_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_history_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The item page's History card (issue #2046).
void main() {
  late String? savedIntlLocale;
  setUp(() {
    savedIntlLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntlLocale);

  final t = DateTime(2026);
  final bill = Diver(id: 'owner', name: 'Bill', createdAt: t, updatedAt: t);
  final anna = Diver(id: 'wife', name: 'Anna', createdAt: t, updatedAt: t);
  final entries = <EquipmentHistoryEntry>[
    EquipmentUsageRun(
      diverId: 'wife',
      first: DateTime(2026, 3, 1),
      last: DateTime(2026, 3, 9),
      diveCount: 4,
    ),
    EquipmentEventEntry(
      EquipmentOwnershipEvent(
        id: 'e',
        equipmentId: 'x',
        kind: EquipmentOwnershipEventKind.shared,
        fromDiverId: 'owner',
        occurredAt: DateTime(2026, 2, 1),
      ),
    ),
    EquipmentUsageRun(
      diverId: 'owner',
      first: DateTime(2026, 1, 2),
      last: DateTime(2026, 1, 2),
      diveCount: 1,
    ),
    EquipmentAddedEntry(ownerId: 'owner', at: DateTime(2026, 1, 1)),
  ];

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    List<Diver>? divers,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(
              child: EquipmentHistoryCard(equipmentId: 'x'),
            ),
          ),
        ),
        GoRoute(
          path: '/dives',
          builder: (_, _) => const Scaffold(body: Text('dive list')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allDiversProvider.overrideWith((ref) async => divers ?? [bill, anna]),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'owner'),
          equipmentHistoryProvider('x').overrideWith((ref) async => entries),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  testWidgets('lists runs, events and the creation, newest first', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.textContaining('4 dives'), findsOneWidget);
    expect(find.text('Shared with a deleted profile'), findsOneWidget);
    expect(find.text('Added by Bill'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Anna')).dy,
      lessThan(tester.getTopLeft(find.text('Added by Bill')).dy),
    );
  });

  testWidgets('hidden with a single profile', (tester) async {
    await pump(tester, divers: [bill]);
    expect(find.text('History'), findsNothing);
  });

  testWidgets('the active diver run opens their filtered dive list', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(find.text('dive list'), findsNothing);

    await tester.tap(find.text('Bill'));
    await tester.pumpAndSettle();
    expect(find.text('dive list'), findsOneWidget);
    expect(container.read(diveFilterProvider).equipmentIds, ['x']);
  });
}
