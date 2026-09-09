import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

class _FakeSettingsRepository extends AppSettingsRepository {
  _FakeSettingsRepository() {
    // Self-registering so no construction site can forget it, and a new
    // one cannot reintroduce the leak.
    addTearDown(settingsTicks.close);
  }

  final List<EquipmentArrangement> written = [];
  final StreamController<void> settingsTicks = StreamController<void>();
  EquipmentArrangement? stored;

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async => stored;

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    written.add(arrangement);
    stored = arrangement;
  }

  @override
  Stream<void> watchSettingsChanges() => settingsTicks.stream;
}

/// The arrange sheet is also reachable from Settings > Appearance, so the
/// choice is findable where a diver looks for display settings.
void main() {
  testWidgets('the appearance page opens the arrange sheet', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = _FakeSettingsRepository();
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          appSettingsRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppearancePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.text('Gear arrangement');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Order types by'), findsOneWidget);
  });
}
