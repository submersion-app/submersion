import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_inbox_page.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeFindingsRepository implements QualityFindingsRepository {
  _FakeFindingsRepository(this.findings);
  List<QualityFinding> findings;
  final dismissed = <String>[];

  @override
  Stream<List<QualityFinding>> watchFindings() => Stream.value(findings);

  @override
  Future<void> setStatus(String id, QualityStatus status) async {
    dismissed.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

QualityFinding finding({String detectorId = 'sample_gap'}) => QualityFinding(
  id: 'f-$detectorId',
  diveId: 'd1',
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.profile,
  severity: QualitySeverity.info,
  status: QualityStatus.open,
  params: const {'gapCount': 2, 'longestGapSeconds': 90},
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

Future<Widget> _wrap(_FakeFindingsRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      qualityFindingsRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DataQualityInboxPage(),
    ),
  );
}

void main() {
  testWidgets('empty inbox shows the all-clear state', (tester) async {
    await tester.pumpWidget(await _wrap(_FakeFindingsRepository([])));
    await tester.pumpAndSettle();
    expect(find.text('All clear'), findsOneWidget);
  });

  testWidgets('a finding renders its detector title', (tester) async {
    await tester.pumpWidget(await _wrap(_FakeFindingsRepository([finding()])));
    await tester.pumpAndSettle();
    expect(find.text('Sample gaps'), findsOneWidget);
  });

  testWidgets('dismiss marks the finding dismissed', (tester) async {
    final repo = _FakeFindingsRepository([finding()]);
    await tester.pumpWidget(await _wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first); // expand
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(repo.dismissed, ['f-sample_gap']);
  });

  testWidgets('expanded card shows exactly one Go to dive link', (
    tester,
  ) async {
    // sample_gap's repair options include a GoToDiveRepair; the card also
    // renders its own footer "Go to dive" -- there must be no duplicate.
    await tester.pumpWidget(await _wrap(_FakeFindingsRepository([finding()])));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first); // expand
    await tester.pumpAndSettle();
    expect(find.text('Go to dive'), findsOneWidget);
  });
}
