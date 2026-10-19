import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

FeatureHealth _h(
  DataFeature feature,
  HealthLevel level, [
  HealthReason reason = HealthReason.ok,
  String? name,
]) => FeatureHealth(feature: feature, level: level, reason: reason, name: name);

final _allGood = [
  _h(DataFeature.backup, HealthLevel.healthy),
  _h(DataFeature.sync, HealthLevel.healthy),
  _h(DataFeature.sharedLibraries, HealthLevel.notSetUp, HealthReason.notSetUp),
  _h(DataFeature.media, HealthLevel.notSetUp, HealthReason.notSetUp),
];

final _mixed = [
  _h(DataFeature.backup, HealthLevel.attention, HealthReason.backupAutoOff),
  _h(DataFeature.sync, HealthLevel.healthy),
  _h(
    DataFeature.sharedLibraries,
    HealthLevel.failing,
    HealthReason.librariesFailed,
    'Club Sites',
  ),
  _h(DataFeature.media, HealthLevel.notSetUp, HealthReason.notSetUp),
];

void main() {
  late List<String> visited;

  Future<void> pump(
    WidgetTester tester,
    List<FeatureHealth> health, {
    Size size = const Size(400, 800),
    double textScale = 1,
  }) async {
    visited = [];
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    GoRoute stub(String path) => GoRoute(
      path: path,
      builder: (context, state) {
        visited.add(path);
        return const Scaffold();
      },
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const Scaffold(body: DataHealthStrip()),
          ),
        ),
        stub('/settings/backup'),
        stub('/settings/cloud-sync'),
        stub('/settings/shared-libraries'),
        stub('/settings/photos-media'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dataHealthProvider.overrideWithValue(health)],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('strip shows four labelled items with semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, _mixed);

    for (final label in ['Backups', 'Sync', 'Libraries', 'Photos']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('Backups: Needs attention'), findsOneWidget);
    expect(find.bySemanticsLabel('Sync: Healthy'), findsOneWidget);
    expect(find.bySemanticsLabel('Libraries: Failing'), findsOneWidget);
    expect(find.bySemanticsLabel('Photos: Not set up'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('attention lines list failing before attention', (tester) async {
    await pump(tester, _mixed);

    const failing = 'Club Sites: sync failed';
    const attention = 'Recommended: turn on automatic backups';
    expect(find.text(failing), findsOneWidget);
    expect(find.text(attention), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(failing)).dy,
      lessThan(tester.getTopLeft(find.text(attention)).dy),
    );
  });

  testWidgets('no attention lines when all healthy or not set up', (
    tester,
  ) async {
    await pump(tester, _allGood);

    expect(find.byKey(const Key('dataHealth_attentionLine')), findsNothing);
  });

  testWidgets('tapping an item and a line navigates to the feature route', (
    tester,
  ) async {
    await pump(tester, _mixed);
    await tester.tap(find.text('Sync'));
    await tester.pumpAndSettle();
    expect(visited, ['/settings/cloud-sync']);

    await pump(tester, _mixed);
    await tester.tap(find.text('Club Sites: sync failed'));
    await tester.pumpAndSettle();
    expect(visited, ['/settings/shared-libraries']);
  });

  testWidgets('strip fits a narrow phone at large text', (tester) async {
    await pump(tester, _mixed, size: const Size(320, 800), textScale: 2);

    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers can activate each strip item', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, _mixed);

    for (final label in [
      'Backups: Needs attention',
      'Sync: Healthy',
      'Libraries: Failing',
      'Photos: Not set up',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isSemantics(label: label, isButton: true, hasTapAction: true),
        reason: label,
      );
    }
    handle.dispose();
  });
}
