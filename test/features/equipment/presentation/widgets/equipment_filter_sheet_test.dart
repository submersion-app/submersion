import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Opens the sheet the way the equipment list does: as a modal bottom sheet
/// handed a [WidgetRef]. Going through a real route keeps "Apply"'s
/// Navigator.pop legitimate.
class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showEquipmentFilterSheet(context, ref),
          child: const Text('open'),
        ),
      ),
    );
  }
}

EquipmentItem _item(String id, EquipmentType type) =>
    EquipmentItem(id: id, name: id, type: type);

final _gear = [
  _item('reg', EquipmentType.regulator),
  _item('bcd', EquipmentType.bcd),
  _item('suit', EquipmentType.wetsuit),
];

Future<ProviderContainer> _container({
  EquipmentFilterState filter = const EquipmentFilterState(),
  List<EquipmentItem>? owned,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      allEquipmentProvider.overrideWith((ref) async => owned ?? _gear),
      equipmentFilterProvider.overrideWith((ref) => filter),
    ],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      // Pinned so assertions on English labels do not depend on the host
      // machine's locale, which flutter_test forwards.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _SheetLauncher(),
    ),
  );
}

/// The sheet lists every status and every owned category, which is taller than
/// a default test window; the overflow is a layout artifact of the surface
/// size, not the behavior under test.
void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1000, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(_app(container));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _statusChip(EquipmentStatus? status) =>
    find.byKey(ValueKey('equipment_filter_status_${status?.name ?? 'all'}'));

Finder _typeChip(EquipmentType? type) =>
    find.byKey(ValueKey('equipment_filter_type_${type?.name ?? 'all'}'));

bool _isSelected(WidgetTester tester, Finder chip) =>
    tester.widget<ChoiceChip>(chip).selected;

void main() {
  group('EquipmentFilterSheet', () {
    testWidgets('opens showing the filter already in force', (tester) async {
      _useTallSurface(tester);
      final container = await _container(
        filter: const EquipmentFilterState(
          status: EquipmentStatus.retired,
          type: EquipmentType.bcd,
        ),
      );

      await _openSheet(tester, container);

      expect(_isSelected(tester, _statusChip(EquipmentStatus.retired)), isTrue);
      expect(_isSelected(tester, _typeChip(EquipmentType.bcd)), isTrue);
      expect(_isSelected(tester, _statusChip(null)), isFalse);
      expect(_isSelected(tester, _typeChip(null)), isFalse);
    });

    testWidgets('offers only the categories the diver owns', (tester) async {
      _useTallSurface(tester);
      final container = await _container();

      await _openSheet(tester, container);

      expect(_typeChip(EquipmentType.regulator), findsOneWidget);
      expect(_typeChip(EquipmentType.bcd), findsOneWidget);
      expect(_typeChip(EquipmentType.wetsuit), findsOneWidget);
      expect(_typeChip(EquipmentType.dpv), findsNothing);
    });

    testWidgets('keeps a selected category the diver no longer owns', (
      tester,
    ) async {
      // Otherwise the filter would be stuck: the panel is the only place it
      // can be turned off from.
      _useTallSurface(tester);
      final container = await _container(
        filter: const EquipmentFilterState(type: EquipmentType.dpv),
        owned: _gear,
      );

      await _openSheet(tester, container);

      expect(_typeChip(EquipmentType.dpv), findsOneWidget);
      expect(_isSelected(tester, _typeChip(EquipmentType.dpv)), isTrue);
    });

    testWidgets('hides the category section when there is no gear', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(owned: const []);

      await _openSheet(tester, container);

      expect(find.text('Category'), findsNothing);
      expect(_typeChip(null), findsNothing);
      // The status axis is still offered.
      expect(_statusChip(null), findsOneWidget);
    });

    testWidgets('writes the provider only on Apply', (tester) async {
      _useTallSurface(tester);
      final container = await _container();

      await _openSheet(tester, container);
      await tester.tap(_typeChip(EquipmentType.bcd));
      await tester.pumpAndSettle();

      expect(container.read(equipmentFilterProvider).type, isNull);

      await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
      await tester.pumpAndSettle();

      expect(container.read(equipmentFilterProvider).type, EquipmentType.bcd);
      expect(find.byType(EquipmentFilterSheet), findsNothing);
    });

    testWidgets('Cancel discards the draft', (tester) async {
      _useTallSurface(tester);
      final container = await _container(
        filter: const EquipmentFilterState(type: EquipmentType.wetsuit),
      );

      await _openSheet(tester, container);
      await tester.tap(_typeChip(EquipmentType.bcd));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        container.read(equipmentFilterProvider).type,
        EquipmentType.wetsuit,
      );
    });

    testWidgets('Clear All empties the draft without touching the list', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(
        filter: const EquipmentFilterState(
          status: EquipmentStatus.retired,
          type: EquipmentType.bcd,
        ),
      );

      await _openSheet(tester, container);
      await tester.tap(find.widgetWithText(TextButton, 'Clear All'));
      await tester.pumpAndSettle();

      expect(_isSelected(tester, _statusChip(null)), isTrue);
      expect(_isSelected(tester, _typeChip(null)), isTrue);
      // Still nothing written until Apply.
      expect(
        container.read(equipmentFilterProvider),
        const EquipmentFilterState(
          status: EquipmentStatus.retired,
          type: EquipmentType.bcd,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
      await tester.pumpAndSettle();

      expect(container.read(equipmentFilterProvider).hasActiveFilters, isFalse);
    });

    testWidgets('picking a status turns Service Due off, and back', (
      tester,
    ) async {
      // The list reads one provider, so the two are a single choice.
      _useTallSurface(tester);
      final container = await _container(
        filter: const EquipmentFilterState(serviceDueOnly: true),
      );

      await _openSheet(tester, container);
      await tester.tap(_statusChip(EquipmentStatus.retired));
      await tester.pumpAndSettle();

      expect(
        _isSelected(
          tester,
          find.byKey(const ValueKey('equipment_filter_status_serviceDue')),
        ),
        isFalse,
      );

      await tester.tap(
        find.byKey(const ValueKey('equipment_filter_status_serviceDue')),
      );
      await tester.pumpAndSettle();
      expect(
        _isSelected(tester, _statusChip(EquipmentStatus.retired)),
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('equipment_filter_apply')));
      await tester.pumpAndSettle();

      final applied = container.read(equipmentFilterProvider);
      expect(applied.serviceDueOnly, isTrue);
      expect(applied.status, isNull);
    });

    testWidgets('needsService is not offered as a status', (tester) async {
      // The computed Service Due choice is what divers mean by it.
      _useTallSurface(tester);
      final container = await _container();

      await _openSheet(tester, container);

      expect(_statusChip(EquipmentStatus.needsService), findsNothing);
      expect(find.text('Service Due'), findsOneWidget);
    });

    testWidgets('sold is offered as a status so sold gear stays reachable', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container();

      await _openSheet(tester, container);

      await tester.scrollUntilVisible(
        _statusChip(EquipmentStatus.sold),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      expect(_statusChip(EquipmentStatus.sold), findsOneWidget);
    });
  });
}
