// Issue #4561: "Back up automatically" carries the backup mark while it is
// off, the reason the Settings > Data row is amber.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_auto_row.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettings extends StateNotifier<BackupSettings>
    implements BackupSettingsNotifier {
  _FakeSettings(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool enabled,
    List<FeatureHealth> findings = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupSettingsProvider.overrideWith(
            (ref) => _FakeSettings(BackupSettings(enabled: enabled)),
          ),
          backupHealthProvider.overrideWithValue(
            pickHealth(DataFeature.backup, findings),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupAutoRow()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('off, it carries the mark', (tester) async {
    await pump(
      tester,
      enabled: false,
      findings: const [
        FeatureHealth(
          feature: DataFeature.backup,
          level: HealthLevel.attention,
          reason: HealthReason.backupAutoOff,
        ),
      ],
    );
    expect(
      tester.widget<HealthSymbol>(find.byType(HealthSymbol)).level,
      HealthLevel.attention,
    );
  });

  testWidgets('on and healthy, it reads as before', (tester) async {
    await pump(tester, enabled: true);
    expect(find.byType(HealthSymbol), findsNothing);
    expect(find.text('Back up automatically'), findsOneWidget);
  });
}
