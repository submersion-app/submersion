import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart' show TankRole;
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_tank_specs_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final presets = TankPresets.all
      .map((p) => TankPresetEntity.fromBuiltIn(p))
      .toList();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        tankPresetListNotifierProvider.overrideWith(
          (ref) => _MockTankPresetListNotifier(presets),
        ),
        tankPresetsProvider.overrideWith((ref) => Future.value(presets)),
      ].cast(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BulkTankSpecsEditor', () {
    // The template writes to every tank on every selected dive, so a numbered
    // "Tank 1" header read as if only the first tank would change (#3367).
    testWidgets('labels the template as all tanks, not tank 1', (tester) async {
      await _pump(
        tester,
        BulkTankSpecsEditor(
          specs: const DiveTank(id: ''),
          fields: const {TankSpecField.volume},
          slotRoles: null,
          onSpecsChanged: (_) {},
          onFieldsChanged: (_) {},
          onSlotRolesChanged: (_) {},
        ),
      );

      final header = find.byType(TankEditor);
      expect(
        find.descendant(of: header, matching: find.text('All tanks')),
        findsOneWidget,
      );
      expect(find.text('Tank 1'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.byIcon(Icons.layers_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.text('1'),
        ),
        findsNothing,
      );
    });
  });

  // Issue #4412: a sidemount pair gets a different role per tank position.
  group('BulkTankSpecsEditor role by position', () {
    final sameRole = find.text('Same role on every tank');
    final byPosition = find.text('Role by tank position');
    final templateRole = find.byKey(const ValueKey('tank-role-backGas'));

    testWidgets('offers the role layout only when Role is ticked', (
      tester,
    ) async {
      await _pump(tester, const _Harness(fields: {TankSpecField.volume}));
      expect(byPosition, findsNothing);

      // A new key, so the harness starts from these fields rather than
      // keeping the state of the first pump.
      await _pump(
        tester,
        const _Harness(key: ValueKey('role'), fields: {TankSpecField.role}),
      );
      expect(sameRole, findsOneWidget);
      expect(byPosition, findsOneWidget);
      expect(templateRole, findsOneWidget);
    });

    // Both choices must fit a phone: a SegmentedButton gave each the width
    // of the longer label and overflowed.
    testWidgets('the role layout fits a phone-width form', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // German has the longest labels.
      await _pump(
        tester,
        const _Harness(fields: {TankSpecField.role}),
        locale: const Locale('de'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Gleiche Rolle für jede Flasche'), findsOneWidget);
      expect(find.text('Rolle nach Flaschenposition'), findsOneWidget);
    });

    testWidgets('by position starts with sidemount left and right', (
      tester,
    ) async {
      final reported = <List<TankRole>?>[];
      await _pump(
        tester,
        _Harness(fields: const {TankSpecField.role}, onSlotRoles: reported.add),
      );

      await tester.tap(byPosition);
      await tester.pumpAndSettle();

      expect(reported.last, [TankRole.sidemountLeft, TankRole.sidemountRight]);
      expect(find.text('Tank 1'), findsOneWidget);
      expect(find.text('Tank 2'), findsOneWidget);
      // The template's own role picker would read as if it still applied.
      expect(templateRole, findsNothing);
    });

    testWidgets('add appends back gas; one position cannot be removed', (
      tester,
    ) async {
      final reported = <List<TankRole>?>[];
      await _pump(
        tester,
        _Harness(
          fields: const {TankSpecField.role},
          slotRoles: const [TankRole.sidemountLeft],
          onSlotRoles: reported.add,
        ),
      );

      final remove = tester.widget<IconButton>(
        find.byKey(const ValueKey('bulk-tank-slot-remove-0')),
      );
      expect(remove.onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('bulk-tank-slot-add')));
      await tester.pumpAndSettle();

      expect(reported.last, [TankRole.sidemountLeft, TankRole.backGas]);
    });

    testWidgets('remove drops that position', (tester) async {
      final reported = <List<TankRole>?>[];
      await _pump(
        tester,
        _Harness(
          fields: const {TankSpecField.role},
          slotRoles: const [TankRole.sidemountLeft, TankRole.sidemountRight],
          onSlotRoles: reported.add,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('bulk-tank-slot-remove-0')));
      await tester.pumpAndSettle();

      expect(reported.last, [TankRole.sidemountRight]);
    });

    testWidgets('changing a position reports the new list', (tester) async {
      final reported = <List<TankRole>?>[];
      await _pump(
        tester,
        _Harness(
          fields: const {TankSpecField.role},
          slotRoles: const [TankRole.sidemountLeft, TankRole.sidemountRight],
          onSlotRoles: reported.add,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('bulk-tank-slot-role-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deco').last);
      await tester.pumpAndSettle();

      expect(reported.last, [TankRole.sidemountLeft, TankRole.deco]);
    });

    testWidgets('same role goes back to the template role', (tester) async {
      final reported = <List<TankRole>?>[];
      await _pump(
        tester,
        _Harness(
          fields: const {TankSpecField.role},
          slotRoles: const [TankRole.sidemountLeft, TankRole.sidemountRight],
          onSlotRoles: reported.add,
        ),
      );

      await tester.tap(sameRole);
      await tester.pumpAndSettle();

      expect(reported.last, isNull);
      expect(templateRole, findsOneWidget);
      expect(find.byKey(const ValueKey('bulk-tank-slot-add')), findsNothing);
    });
  });

  group('TankEditor header', () {
    testWidgets('a dive tank keeps its number', (tester) async {
      await _pump(
        tester,
        TankEditor(
          tank: const DiveTank(id: 't2'),
          tankNumber: 2,
          onChanged: (_) {},
        ),
      );

      expect(find.text('Tank 2'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.layers_outlined), findsNothing);
    });
  });
}

/// Holds the editor's state the way the bulk form does, reporting each slot
/// role change.
class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.fields,
    this.slotRoles,
    this.onSlotRoles,
  });

  final Set<TankSpecField> fields;
  final List<TankRole>? slotRoles;
  final ValueChanged<List<TankRole>?>? onSlotRoles;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Set<TankSpecField> _fields = widget.fields;
  late List<TankRole>? _slotRoles = widget.slotRoles;
  DiveTank _specs = const DiveTank(id: 'bulk-tank-specs');

  @override
  Widget build(BuildContext context) => BulkTankSpecsEditor(
    specs: _specs,
    fields: _fields,
    slotRoles: _slotRoles,
    onSpecsChanged: (t) => setState(() => _specs = t),
    onFieldsChanged: (f) => setState(() => _fields = f),
    onSlotRolesChanged: (r) {
      setState(() => _slotRoles = r);
      widget.onSlotRoles?.call(r);
    },
  );
}

class _MockTankPresetListNotifier
    extends StateNotifier<AsyncValue<List<TankPresetEntity>>>
    implements TankPresetListNotifier {
  _MockTankPresetListNotifier(List<TankPresetEntity> presets)
    : super(AsyncValue.data(presets));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
