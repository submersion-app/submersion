import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/nav_track_fixtures.dart';

final _dive = Dive(
  id: 'nav-vis',
  diveNumber: 1,
  dateTime: DateTime(2025, 8, 22, 10),
  maxDepth: 20.0,
);

/// [routes] is read on every build of the overridden provider, so a test
/// can change it and invalidate the provider to simulate an unlink.
Future<void> _pump(
  WidgetTester tester,
  Future<List<NavTrack>> Function() routes,
) async {
  tester.view.physicalSize = const Size(950, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final originalOnError = FlutterError.onError;
  // Restored by teardown, so a pump that throws cannot leak the filter into
  // the next test file sharing this isolate.
  addTearDown(() => FlutterError.onError = originalOnError);
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveProvider(_dive.id).overrideWith((ref) async => _dive),
        diveDataSourcesProvider(_dive.id).overrideWith((ref) async => const []),
        navTracksForDiveProvider(_dive.id).overrideWith((ref) => routes()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: _dive.id, embedded: true),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('no Underwater Route card when no route is linked', (
    tester,
  ) async {
    await _pump(tester, () async => const []);
    expect(find.text('Underwater Route'), findsNothing);
    expect(find.text('No route linked'), findsNothing);
  });

  testWidgets('no card while the dive\'s routes are still loading', (
    tester,
  ) async {
    final never = Completer<List<NavTrack>>();
    await _pump(tester, () => never.future);
    expect(find.text('Underwater Route'), findsNothing);
  });

  testWidgets('shows the card once a route is linked, and hides it again '
      'when the last route goes', (tester) async {
    var linked = [testNavTrack('r1', diveId: _dive.id)];
    await _pump(tester, () async => linked);
    expect(find.text('Underwater Route'), findsOneWidget);

    linked = const [];
    ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).invalidate(navTracksForDiveProvider(_dive.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Underwater Route'), findsNothing);
  });
}
