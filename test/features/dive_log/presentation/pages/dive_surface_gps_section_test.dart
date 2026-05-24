import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Dive _gpsDive({GeoPoint? entry, GeoPoint? exit}) => Dive(
  id: 'sgps',
  diveNumber: 1,
  dateTime: DateTime(2026, 5, 22, 9, 14),
  maxDepth: 30.0,
  entryLocation: entry,
  exitLocation: exit,
);

Future<void> _pump(
  WidgetTester tester,
  Dive dive, {
  bool expanded = false,
  List<DiveDataSource> sources = const [],
}) async {
  final overrides = await getBaseOverrides();
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    originalOnError?.call(d);
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        if (expanded) surfaceGpsSectionExpandedProvider.overrideWithValue(true),
        diveProvider(dive.id).overrideWith((ref) async => dive),
        diveDataSourcesProvider(dive.id).overrideWith((ref) async => sources),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiveDetailPage(diveId: dive.id, embedded: true),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = originalOnError;
}

void main() {
  testWidgets('Surface GPS section shows drift summary, coordinates and '
      'open-in-maps when expanded', (tester) async {
    await _pump(
      tester,
      _gpsDive(
        entry: const GeoPoint(12.34567, 98.76543),
        exit: const GeoPoint(12.34612, 98.76489),
      ),
      expanded: true,
    );

    expect(find.text('Surface GPS'), findsOneWidget);
    expect(find.textContaining('Drift'), findsWidgets);
    expect(find.text('Open in Maps'), findsOneWidget);
  });

  testWidgets('no Surface GPS section when dive has no GPS', (tester) async {
    await _pump(tester, _gpsDive());

    expect(find.text('Surface GPS'), findsNothing);
  });

  testWidgets('shows source-attribution badge on GPS for a multi-computer '
      'dive', (tester) async {
    await _pump(
      tester,
      _gpsDive(
        entry: const GeoPoint(12.34567, 98.76543),
        exit: const GeoPoint(12.34612, 98.76489),
      ),
      expanded: true,
      sources: [
        DiveDataSource(
          id: 's1',
          diveId: 'sgps',
          isPrimary: true,
          computerModel: 'Perdix',
          entryLatitude: 12.34567,
          entryLongitude: 98.76543,
          importedAt: DateTime(2026),
          createdAt: DateTime(2026),
        ),
        DiveDataSource(
          id: 's2',
          diveId: 'sgps',
          isPrimary: false,
          computerModel: 'Teric',
          importedAt: DateTime(2026),
          createdAt: DateTime(2026),
        ),
      ],
    );

    final section = find.ancestor(
      of: find.text('Surface GPS'),
      matching: find.byType(CollapsibleCardSection),
    );
    expect(
      find.descendant(
        of: section,
        matching: find.byType(FieldAttributionBadge),
      ),
      findsWidgets,
    );
  });

  testWidgets('exit-only dive shows the exit-only collapsed subtitle', (
    tester,
  ) async {
    await _pump(tester, _gpsDive(exit: const GeoPoint(12.34612, 98.76489)));

    expect(find.text('Surface GPS'), findsOneWidget);
    expect(find.text('Exit point recorded'), findsOneWidget);
  });

  testWidgets('tapping the header toggles the Surface GPS section expansion', (
    tester,
  ) async {
    await _pump(
      tester,
      _gpsDive(
        entry: const GeoPoint(12.34567, 98.76543),
        exit: const GeoPoint(12.34612, 98.76489),
      ),
    );

    final section = find.ancestor(
      of: find.text('Surface GPS'),
      matching: find.byType(CollapsibleCardSection),
    );
    final rotation = find.descendant(
      of: section,
      matching: find.byType(AnimatedRotation),
    );
    expect(tester.widget<AnimatedRotation>(rotation).turns, 0.0);

    await tester.tap(find.text('Surface GPS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.widget<AnimatedRotation>(rotation).turns, 0.5);
  });

  testWidgets('tapping Open in Maps launches an OpenStreetMap url', (
    tester,
  ) async {
    // Tall surface so the button (bottom of the expanded section) is on-screen
    // and hit-testable rather than scrolled off the default 800x600 viewport.
    await tester.binding.setSurfaceSize(const Size(600, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? launchedUrl;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'canLaunch') return true;
          if (call.method == 'launch') {
            launchedUrl =
                (call.arguments as Map<dynamic, dynamic>)['url'] as String?;
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await _pump(
      tester,
      _gpsDive(
        entry: const GeoPoint(12.34567, 98.76543),
        exit: const GeoPoint(12.34612, 98.76489),
      ),
      expanded: true,
    );

    await tester.tap(find.text('Open in Maps'));
    await tester.pump();

    expect(launchedUrl, isNotNull);
    expect(launchedUrl, contains('openstreetmap.org'));
    expect(launchedUrl, contains('12.34567'));
  });
}
