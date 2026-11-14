import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_color_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_color_field.dart';
import 'package:submersion/features/settings/domain/list_arrangements.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The field with [settings] as the diver's settings and [gear] as the
/// colours on their gear (issue #4537).
Widget _field({
  String? hex,
  ValueChanged<String>? onChanged,
  VoidCallback? onCleared,
  MockSettingsNotifier? settings,
  Future<List<String>> Function()? gear,
}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => settings ?? MockSettingsNotifier()),
    equipmentGearColorsProvider.overrideWith(
      (ref) => gear?.call() ?? Future.value(const <String>[]),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: EquipmentColorField(
        label: 'Color',
        hex: hex,
        onChanged: onChanged ?? (_) {},
        onCleared: onCleared ?? () {},
      ),
    ),
  ),
);

MockSettingsNotifier _remembering(List<String> colors) => MockSettingsNotifier(
  AppSettings(
    listArrangements: ListArrangements(
      recentEquipmentColors: '[${colors.map((c) => '"$c"').join(',')}]',
    ),
  ),
);

void main() {
  testWidgets('unset shows the placeholder and no clear button', (
    tester,
  ) async {
    await tester.pumpWidget(_field());
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('a value that is not a colour reads as unset', (tester) async {
    await tester.pumpWidget(_field(hex: 'Red'));
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('a palette colour shows its name and swatch', (tester) async {
    await tester.pumpWidget(_field(hex: '#EF4444'));
    expect(find.text('Red'), findsOneWidget);
    expect(find.byKey(const ValueKey('color-field-swatch')), findsOneWidget);
  });

  testWidgets('a colour outside the palette shows its nearest name and code '
      '(#4537)', (tester) async {
    await tester.pumpWidget(_field(hex: '#FF6A00'));
    expect(find.text('Orange (#FF6A00)'), findsOneWidget);
  });

  testWidgets('picking a colour reports it', (tester) async {
    String? picked;
    await tester.pumpWidget(_field(onChanged: (hex) => picked = hex));
    await tester.tap(find.byType(EquipmentColorField));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-#22C55E')));
    await tester.pumpAndSettle();
    expect(picked, '#22C55E');
  });

  testWidgets('None in the sheet clears', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      _field(hex: '#EF4444', onCleared: () => cleared = true),
    );
    await tester.tap(find.text('Red'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-swatch-none')));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
  });

  testWidgets('the clear button clears without opening the sheet', (
    tester,
  ) async {
    var cleared = false;
    await tester.pumpWidget(
      _field(hex: '#EF4444', onCleared: () => cleared = true),
    );
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(cleared, isTrue);
    expect(find.text('Choose a color'), findsNothing);
  });

  group('recent colours (#4537)', () {
    testWidgets('the sheet offers remembered colours, then gear colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        _field(
          settings: _remembering(['#FF6A00']),
          gear: () async => ['#0A3D91', '#FF6A00'],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EquipmentColorField));
      await tester.pumpAndSettle();
      final remembered = tester.getCenter(
        find.byKey(const ValueKey('color-swatch-recent-#FF6A00')),
      );
      final gear = tester.getCenter(
        find.byKey(const ValueKey('color-swatch-recent-#0A3D91')),
      );
      expect(remembered.dx, lessThan(gear.dx));
    });

    testWidgets('Use in the custom dialog remembers the colour first', (
      tester,
    ) async {
      final settings = _remembering(['#0A3D91']);
      String? picked;
      await tester.pumpWidget(
        _field(settings: settings, onChanged: (hex) => picked = hex),
      );
      await tester.tap(find.byType(EquipmentColorField));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('color-swatch-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-color-hex')),
        'ff6a00',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('custom-color-use')));
      await tester.pumpAndSettle();
      expect(picked, '#FF6A00');
      expect(
        settings.state.listArrangements.recentEquipmentColors,
        '["#FF6A00","#0A3D91"]',
      );
    });

    testWidgets('a failed gear lookup still opens the sheet', (tester) async {
      await tester.pumpWidget(
        _field(
          settings: _remembering(['#FF6A00']),
          gear: () => Future.error(StateError('database closed')),
        ),
      );
      await tester.tap(find.byType(EquipmentColorField));
      await tester.pumpAndSettle();
      expect(find.text('Choose a color'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('color-swatch-recent-#FF6A00')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('color-swatch-#EF4444')),
        findsOneWidget,
      );
    });

    testWidgets('a gear colour added after the first open is offered next '
        'time', (tester) async {
      // The real provider's refresh: a pause-aware tick (issue #4537).
      final ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      var gear = const <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            equipmentGearColorsProvider.overrideWith((ref) {
              ref.invalidateSelfWhen(ticks.stream);
              return Future.value(gear);
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EquipmentColorField(
                label: 'Color',
                hex: null,
                onChanged: (_) {},
                onCleared: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(EquipmentColorField));
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // An import or a sync pull colours another item.
      gear = const ['#FF6A00'];
      ticks.add(null);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(EquipmentColorField));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('color-swatch-recent-#FF6A00')),
        findsOneWidget,
      );
    });

    testWidgets('typing a palette code picks it without remembering it', (
      tester,
    ) async {
      final settings = _remembering(['#0A3D91']);
      String? picked;
      await tester.pumpWidget(
        _field(settings: settings, onChanged: (hex) => picked = hex),
      );
      await tester.tap(find.byType(EquipmentColorField));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('color-swatch-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('custom-color-hex')),
        'f97316',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('custom-color-use')));
      await tester.pumpAndSettle();
      expect(picked, '#F97316');
      expect(
        settings.state.listArrangements.recentEquipmentColors,
        '["#0A3D91"]',
      );
    });
  });
}
