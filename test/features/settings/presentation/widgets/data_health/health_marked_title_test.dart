// Issue #4561: a feature page item carries its feature's health mark when a
// finding is about it, and reads as before otherwise.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_marked_title.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  FeatureHealth backup(List<FeatureHealth> findings) =>
      pickHealth(DataFeature.backup, findings);

  FeatureHealth finding(HealthReason reason, {String? subjectId}) =>
      FeatureHealth(
        feature: DataFeature.backup,
        level: HealthLevel.attention,
        reason: reason,
        subjectId: subjectId,
      );

  Future<void> pump(
    WidgetTester tester,
    FeatureHealth health,
    HealthMarkedTitle title,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [backupHealthProvider.overrideWith((ref) => health)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: title),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('no finding shows the title alone', (tester) async {
    await pump(
      tester,
      backup(const []),
      const HealthMarkedTitle(
        title: Text('Back up automatically'),
        feature: DataFeature.backup,
        reasons: {HealthReason.backupAutoOff},
      ),
    );
    expect(find.text('Back up automatically'), findsOneWidget);
    expect(find.byType(HealthSymbol), findsNothing);
  });

  testWidgets('a matching finding adds its mark and says why', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      backup([finding(HealthReason.backupAutoOff)]),
      const HealthMarkedTitle(
        title: Text('Back up automatically'),
        feature: DataFeature.backup,
        reasons: {HealthReason.backupAutoOff},
      ),
    );
    final symbol = tester.widget<HealthSymbol>(find.byType(HealthSymbol));
    expect(symbol.level, HealthLevel.attention);
    expect(symbol.size, 16);
    expect(
      symbol.semanticLabel,
      '${healthLevelLabel(l10n, HealthLevel.attention)}, '
      '${l10n.dataHealth_backup_autoOff}',
    );
    handle.dispose();
  });

  testWidgets('a subject mark ignores another subject', (tester) async {
    await pump(
      tester,
      backup([finding(HealthReason.backupExtraCopyMissing, subjectId: 'x')]),
      const HealthMarkedTitle(
        title: Text('Copy to Dropbox'),
        feature: DataFeature.backup,
        reasons: {HealthReason.backupExtraCopyMissing},
        subjectId: 'y',
      ),
    );
    expect(find.byType(HealthSymbol), findsNothing);
  });
}
