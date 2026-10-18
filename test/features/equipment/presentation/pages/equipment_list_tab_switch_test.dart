import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/equipment_query_fakes.dart';
import '../../../../helpers/mock_providers.dart';

/// Switching between Equipment and Sets shows the chosen section at once,
/// while the pill is still sliding to its name. Issue #3461 is that the page
/// only changed once the slide had finished.

class _MockEquipNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>>
    implements EquipmentListNotifier {
  _MockEquipNotifier() : super(const AsyncValue.data(<EquipmentItem>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _EmptyTagList extends StateNotifier<AsyncValue<List<Tag>>>
    implements TagListNotifier {
  _EmptyTagList() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptySetList extends StateNotifier<AsyncValue<List<EquipmentSet>>>
    implements EquipmentSetListNotifier {
  _EmptySetList() : super(const AsyncValue.data(<EquipmentSet>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(
  WidgetTester tester, {
  required Size window,
  String initialLocation = '/equipment',
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = window;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/equipment',
        builder: (context, state) => const EquipmentListPage(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        equipmentByStatusProvider.overrideWith(
          (ref, status) => <EquipmentItem>[],
        ),
        activeEquipmentProvider.overrideWith((ref) async => <EquipmentItem>[]),
        equipmentListNotifierProvider.overrideWith(
          (ref) => _MockEquipNotifier(),
        ),
        tagListNotifierProvider.overrideWith((ref) => _EmptyTagList()),
        equipmentSetListNotifierProvider.overrideWith((ref) => _EmptySetList()),
        fakeEquipmentQueryIds(),
        allEquipmentProvider.overrideWith((ref) async => <EquipmentItem>[]),
        equipmentListViewModeProvider.overrideWith(
          (ref) => ListViewMode.detailed,
        ),
        equipmentSortProvider.overrideWith(
          (ref) => const SortState(
            field: EquipmentSortField.name,
            direction: SortDirection.ascending,
          ),
        ),
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
}

final _switcher = find.byKey(const ValueKey('equipment_section_toggle'));
final _equipmentPane = find.byKey(const ValueKey('equipment-master-detail'));
final _setsPane = find.byKey(const ValueKey('sets-master-detail'));

Future<AppLocalizations> _en() =>
    AppLocalizations.delegate.load(const Locale('en'));

/// Taps a section name and pumps one frame: the pill has started to slide,
/// nowhere near finished.
Future<void> _tapSection(WidgetTester tester, String name) async {
  await tester.tap(find.descendant(of: _switcher, matching: find.text(name)));
  await tester.pump();
  expect(
    tester.binding.hasScheduledFrame,
    isTrue,
    reason: 'the pill should still be sliding',
  );
}

void main() {
  group('Equipment / Sets switch shows at once (issue #3461)', () {
    testWidgets('wide: the Sets pane shows while the pill slides', (
      tester,
    ) async {
      await _pump(tester, window: const Size(1400, 900));
      final l10n = await _en();
      expect(_equipmentPane, findsOneWidget);

      await _tapSection(tester, l10n.equipment_tab_sets);
      expect(_setsPane, findsOneWidget);
      expect(_equipmentPane, findsNothing);

      // And it stays there once the slide lands.
      await tester.pumpAndSettle();
      expect(_setsPane, findsOneWidget);

      await _tapSection(tester, l10n.equipment_tab_equipment);
      expect(_equipmentPane, findsOneWidget);
      expect(_setsPane, findsNothing);
      await tester.pumpAndSettle();
      expect(_equipmentPane, findsOneWidget);
    });

    testWidgets('wide: tapping back mid-slide lands on the last tapped', (
      tester,
    ) async {
      await _pump(tester, window: const Size(1400, 900));
      final l10n = await _en();

      // The first slide's landing notification arrives after the second tap.
      await _tapSection(tester, l10n.equipment_tab_sets);
      await _tapSection(tester, l10n.equipment_tab_equipment);
      expect(_equipmentPane, findsOneWidget);
      expect(_setsPane, findsNothing);

      await tester.pumpAndSettle();
      expect(_equipmentPane, findsOneWidget);
      expect(_setsPane, findsNothing);
    });

    testWidgets('wide: switching still clears the other section selection', (
      tester,
    ) async {
      await _pump(
        tester,
        window: const Size(1400, 900),
        initialLocation: '/equipment?mode=new',
      );
      final l10n = await _en();
      final router = GoRouter.of(tester.element(_switcher));

      await _tapSection(tester, l10n.equipment_tab_sets);
      await tester.pumpAndSettle();

      expect(_setsPane, findsOneWidget);
      expect(router.state.uri.toString(), '/equipment');
    });

    testWidgets('phone: the Sets FAB and header show while the pill slides', (
      tester,
    ) async {
      await _pump(tester, window: const Size(390, 844));
      final l10n = await _en();
      expect(find.text(l10n.equipment_fab_addEquipment), findsOneWidget);

      await _tapSection(tester, l10n.equipment_tab_sets);
      expect(find.text(l10n.equipment_fab_addSet), findsOneWidget);
      expect(find.text(l10n.equipment_fab_addEquipment), findsNothing);
      // Sets has no actions of its own.
      expect(find.byIcon(Icons.search), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(EquipmentSetListContent), findsOneWidget);
      expect(find.text(l10n.equipment_fab_addSet), findsOneWidget);
    });
  });
}
