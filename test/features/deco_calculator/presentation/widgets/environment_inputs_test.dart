import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';
import 'package:submersion/features/deco_calculator/presentation/widgets/environment_inputs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late String? previousLocale;
  setUp(() => previousLocale = Intl.defaultLocale);
  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('unreadable altitude keeps the calculator altitude instead of '
      'dropping to sea level (#1900)', (tester) async {
    Intl.defaultLocale = 'en_US';
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const EnvironmentInputs(),
      ),
    );
    await tester.pumpAndSettle();

    final altitudeField = find.byType(TextFormField).first;
    await tester.enterText(altitudeField, '2000');
    await tester.pump();
    await tester.enterText(altitudeField, '2..000');
    await tester.pump();

    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EnvironmentInputs)),
    );
    expect(
      container.read(calcAltitudeProvider),
      2000,
      reason: 'unreadable text used to reset the altitude to sea level',
    );
  });

  testWidgets('a below-sea-level altitude keeps its sign (#1900 review)', (
    tester,
  ) async {
    Intl.defaultLocale = 'en_US';
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: const EnvironmentInputs(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '-430');
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(EnvironmentInputs)),
    );
    expect(container.read(calcAltitudeProvider), -430);
  });
}
