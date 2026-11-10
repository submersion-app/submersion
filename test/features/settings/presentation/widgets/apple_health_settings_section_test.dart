import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/health_settings_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/apple_health_settings_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _Health extends Fake implements HealthImportService {
  _Health({this.completes = true});

  final bool completes;
  final asked = <String>[];

  @override
  Future<bool> requestPermissions() async {
    asked.add('dives');
    return completes;
  }

  @override
  Future<bool> requestMetricsPermissions() async {
    asked.add('metrics');
    return completes;
  }
}

/// The Apple Health switches (issue #637): iOS only, each asks Health for
/// what it reads, and names the diver it belongs to.
void main() {
  Future<_Health> pump(WidgetTester tester, {bool completes = true}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final health = _Health(completes: completes);
    final diver = Diver(
      id: 'a',
      name: 'Alex',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          healthImportServiceProvider.overrideWithValue(health),
          healthSettingsProvider.overrideWith(
            (ref) =>
                HealthSettingsNotifier(prefs, diverExists: (_) async => true),
          ),
          allDiversProvider.overrideWith((ref) async => [diver]),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AppleHealthSettingsSection()),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('a');
    await tester.pumpAndSettle();
    return health;
  }

  testWidgets('shows nothing off iOS', (tester) async {
    await pump(tester);

    expect(find.byType(SwitchListTile), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('turning on automatic import asks Health and binds the diver', (
    tester,
  ) async {
    final health = await pump(tester);

    await tester.tap(find.text('Import Apple Watch dives automatically'));
    await tester.pumpAndSettle();

    expect(health.asked, ['dives']);
    expect(find.text('For: Alex'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('turning on heart rate asks Health for heart rate and sleep', (
    tester,
  ) async {
    final health = await pump(tester);

    await tester.tap(find.text('Heart rate, recovery and sleep'));
    await tester.pumpAndSettle();

    expect(health.asked, ['metrics']);
    expect(find.text('For: Alex'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a request that fails leaves the switch off', (tester) async {
    await pump(tester, completes: false);

    await tester.tap(find.text('Import Apple Watch dives automatically'));
    await tester.pumpAndSettle();

    expect(find.text('For: Alex'), findsNothing);
    final tile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile).first,
    );
    expect(tile.value, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
