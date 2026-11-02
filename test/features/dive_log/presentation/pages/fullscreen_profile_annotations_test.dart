import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, DiveProfileEvent;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/fullscreen_profile_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_marker_layer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/annotation_placement_banner.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The fullscreen profile (#4109) draws the dive's annotations and can place
/// one from its own pin.
void main() {
  late DiveRepository repository;
  late String? previousLocale;
  const diveId = 'dive-full';

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  AppDatabase db() => DatabaseService.instance.database;

  Future<void> seed() async {
    await repository.createDive(
      Dive(
        id: diveId,
        dateTime: DateTime.utc(2026, 5, 3, 10),
        runtime: const Duration(seconds: 1200),
        maxDepth: 30,
        profile: List.generate(
          41,
          (i) => DiveProfilePoint(timestamp: i * 30, depth: i < 20 ? 30 : 10),
        ),
        notes: 'First.\n\n[felt sick](annotation:a1)',
      ),
    );
    await db().customStatement(
      'INSERT INTO dive_profile_events '
      '(id, dive_id, timestamp, event_type, source, description, depth, '
      'created_at) '
      "VALUES ('a1', '$diveId', 300, 'annotation', 'user', 'felt sick', 30, 1)",
    );
  }

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<List<DiveProfileEvent>> rows() =>
      (db().select(db().diveProfileEvents)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  /// Pushes the page over a plain route, the way a caller opens it.
  Future<void> pumpPage(
    WidgetTester tester, {
    ValueChanged<String>? onOpenInNotes,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FullscreenProfilePage(
                    diveId: diveId,
                    onOpenInNotes: onOpenInNotes,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> tapDot(WidgetTester tester) async {
    final layerFinder = find.byType(AnnotationMarkerLayer);
    final layer = tester.widget<AnnotationMarkerLayer>(layerFinder);
    final center = annotationDotCenters(
      annotations: layer.annotations,
      size: tester.getSize(layerFinder),
      insets: layer.insets,
      visibleMinSeconds: layer.visibleMinSeconds,
      visibleMaxSeconds: layer.visibleMaxSeconds,
      visibleMinDepth: layer.visibleMinDepth,
      visibleMaxDepth: layer.visibleMaxDepth,
      depthAt: layer.depthAt,
    ).single!;
    await tester.tapAt(tester.getTopLeft(layerFinder) + center);
    await settle(tester, frames: 4);
  }

  testWidgets('Open in Notes pops and hands the annotation to the caller', (
    tester,
  ) async {
    await seed();
    final opened = <String>[];
    await pumpPage(tester, onOpenInNotes: opened.add);

    await tapDot(tester);
    await tester.tap(find.text('Open in Notes'));
    await settle(tester);

    expect(opened, ['a1']);
    expect(find.byType(FullscreenProfilePage), findsNothing);
  });

  testWidgets('opened with no Notes card behind it, as the dashboard does, '
      'the popup offers no Open in Notes', (tester) async {
    await seed();
    await pumpPage(tester);

    await tapDot(tester);

    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Open in Notes'), findsNothing);
  });

  testWidgets('draws annotations and can place one', (tester) async {
    await seed();
    await pumpPage(tester);
    expect(find.byType(AnnotationMarkerLayer), findsOneWidget);

    await tester.tap(find.byTooltip('Add annotation'));
    await settle(tester, frames: 3);
    expect(find.byType(AnnotationPlacementBanner), findsOneWidget);

    final plot = tester.getRect(find.byType(LineChart).first);
    await tester.tapAt(Offset(plot.left + plot.width * 0.75, plot.center.dy));
    await settle(tester, frames: 4);
    expect(find.text('New annotation'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'What happened'),
      'Lost the buddy',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    final all = await rows();
    expect(all, hasLength(2));
    expect(all.last.description, 'Lost the buddy');
    expect(all.last.timestamp, inInclusiveRange(700, 1200));
    expect(find.byType(AnnotationPlacementBanner), findsNothing);
  });
}
