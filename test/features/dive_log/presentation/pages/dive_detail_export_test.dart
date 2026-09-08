import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_source_fetch.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records which delivery the single-dive export sheet chose.
///
/// Only the methods that sheet can reach are implemented; anything else
/// throws via [noSuchMethod] rather than silently returning null.
class _RecordingExportService implements ExportService {
  final calls = <String>[];
  List<DiveSite>? uddfSites;

  /// Return value for every `save*ToFile`; null simulates a cancelled panel.
  String? savePath = '/tmp/export_out';

  /// When set, the next delivery throws this instead of returning.
  Object? failure;

  /// When set, deliveries block on this until the test completes it, so the
  /// progress dialog is observable mid-flight.
  Completer<void>? gate;

  Future<String> _share(String label) async {
    calls.add('share:$label');
    await gate?.future;
    if (failure != null) throw failure!;
    return '/tmp/shared_$label';
  }

  Future<String?> _save(String label) async {
    calls.add('save:$label');
    await gate?.future;
    if (failure != null) throw failure!;
    return savePath;
  }

  /// The personalization the single-dive PDF route passed through.
  Diver? pdfDiver;
  Uint8List? pdfDiverPhoto;

  @override
  Future<({List<int> bytes, String fileName})> generateDivePdfBytes(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    String title = 'Dive Logbook',
    Map<String, PdfProfileSeries>? profiles,
    List<Certification>? certifications,
    Diver? diver,
    Uint8List? diverPhoto,
  }) async {
    calls.add('generate:pdf');
    pdfDiver = diver;
    pdfDiverPhoto = diverPhoto;
    if (failure != null) throw failure!;
    return (bytes: const <int>[1], fileName: 'dive.pdf');
  }

  @override
  Future<String?> savePdfToFile(List<int> bytes, String fileName) =>
      _save('pdf');

  @override
  Future<String> exportDivesToCsv(List<Dive> dives) => _share('csv');

  @override
  Future<String?> saveDivesCsvToFile(List<Dive> dives) => _save('csv');

  @override
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    uddfSites = sites;
    return _share('uddf');
  }

  @override
  Future<String?> saveDivesToUddfFile(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
    List<DiveSourceExport>? dataSources,
    UddfExportOptions options = const UddfExportOptions(),
  }) async {
    uddfSites = sites;
    return _save('uddf');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _RecordingExportService exportService;
  late Dive dive;

  setUp(() {
    exportService = _RecordingExportService();
    final dt = DateTime(2026, 3, 4, 10);
    dive = Dive(
      id: 'dive-1',
      dateTime: dt,
      entryTime: dt,
      diveNumber: 7,
      site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    );
  });

  /// Pumps the detail page and opens the export sheet from the overflow menu.
  ///
  /// The page is hosted in a [Scaffold] because `embedded: true` is the
  /// master-detail pane variant: in the app it renders inside the shell's
  /// Scaffold, which is what the export flow's snackbars attach to.
  Future<void> pumpAndOpenExportSheet(
    WidgetTester tester, {
    Diver? diver,
    DiverPhotoLoader? photoLoader,
  }) async {
    final base = await getBaseOverrides();

    // A tall surface so the export sheet is not clipped by the default
    // 600x800 test viewport.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The page overflows in the test viewport; those layout warnings are noise
    // here.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          exportServiceProvider.overrideWithValue(exportService),
          // These tests have no database. The real fetch would reach the
          // repository, so the export would never be issued.
          uddfSourceFetchProvider.overrideWithValue(
            (diveIds, options) async => const [],
          ),
          // The PDF route enriches the export with buddies, certifications
          // and the diver; those reads reach a database widget tests have
          // not got, and never settle.
          buddiesForDiveProvider(dive.id).overrideWith((ref) async => const []),
          allCertificationsProvider.overrideWith((ref) async => const []),
          currentDiverProvider.overrideWith((ref) async => diver),
          // The real loader reads the file system, and a dart:io await never
          // completes inside testWidgets' FakeAsync zone.
          if (photoLoader != null)
            diverPhotoLoaderProvider.overrideWithValue(photoLoader),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
  }

  /// Picks [format] from the export sheet, then [destination] from the
  /// Share/Save sheet that follows.
  Future<void> chooseFormatAndDestination(
    WidgetTester tester,
    String format,
    String destination,
  ) async {
    await tester.tap(find.text(format));
    await tester.pumpAndSettle();
    await tester.tap(find.text(destination));
    await tester.pumpAndSettle();
  }

  /// The single-dive PDF route asks where to put the file first, then which
  /// template to use. That is the opposite order from the bulk route, whose
  /// picker precedes its destination sheet.
  Future<void> choosePdfAndDestination(
    WidgetTester tester,
    String destination,
  ) async {
    await tester.tap(find.text('PDF Logbook Entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(destination));
    await tester.pumpAndSettle();
    // The template picker's confirm button.
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();
  }

  group('single-dive PDF carries the diver portrait', () {
    // This route passed `diver` but never `diverPhoto`, so the Detailed
    // front matter fell back to its placeholder frame here while the
    // settings export rendered the real portrait.
    final diver = Diver(
      id: 'me',
      name: 'Ada',
      photoPath: '/portraits/ada.jpg',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final portrait = Uint8List.fromList([4, 5, 6]);

    testWidgets('the loaded portrait reaches the export service', (
      tester,
    ) async {
      await pumpAndOpenExportSheet(
        tester,
        diver: diver,
        photoLoader: (path) async =>
            path == '/portraits/ada.jpg' ? portrait : null,
      );
      await choosePdfAndDestination(tester, 'Save to Files');

      expect(exportService.pdfDiver?.id, 'me');
      expect(exportService.pdfDiverPhoto, portrait);
    });

    testWidgets('an unreadable portrait still exports the dive', (
      tester,
    ) async {
      await pumpAndOpenExportSheet(
        tester,
        diver: diver,
        photoLoader: (path) async => null,
      );
      await choosePdfAndDestination(tester, 'Save to Files');

      expect(exportService.calls, contains('generate:pdf'));
      expect(exportService.pdfDiverPhoto, isNull);
      expect(
        exportService.pdfDiver?.id,
        'me',
        reason: 'a missing portrait must not drop the diver as well',
      );
    });
  });

  testWidgets('CSV export offers a save destination and uses it', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Save to File');

    expect(exportService.calls, ['save:csv']);
    expect(find.text('Dive exported successfully'), findsOneWidget);
  });

  testWidgets('CSV export can still share', (tester) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Share');

    expect(exportService.calls, ['share:csv']);
    expect(find.text('Dive exported successfully'), findsOneWidget);
  });

  testWidgets('UDDF export passes the dive site through either delivery', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'UDDF', 'Save to File');

    expect(exportService.calls, ['save:uddf']);
    expect(exportService.uddfSites?.map((s) => s.id), ['site-1']);
  });

  testWidgets('cancelling the save panel is not reported as success', (
    tester,
  ) async {
    exportService.savePath = null;
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Save to File');

    expect(exportService.calls, ['save:csv']);
    expect(find.text('Dive exported successfully'), findsNothing);
  });

  testWidgets('dismissing the destination sheet exports nothing', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();

    // Tap the scrim above the destination sheet.
    await tester.tapAt(const Offset(400, 60));
    await tester.pumpAndSettle();

    expect(exportService.calls, isEmpty);
    expect(find.text('Dive exported successfully'), findsNothing);
  });

  testWidgets('UDDF export can still share, with the dive site', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'UDDF', 'Share');

    expect(exportService.calls, ['share:uddf']);
    expect(exportService.uddfSites?.map((s) => s.id), ['site-1']);
  });

  testWidgets('sharing shows a progress dialog until the export lands', (
    tester,
  ) async {
    final gate = Completer<void>();
    exportService.gate = gate;

    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(find.text('Exporting...'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Exporting...'), findsNothing);
    expect(find.text('Dive exported successfully'), findsOneWidget);
  });

  testWidgets('saving does not raise the progress dialog over the save panel', (
    tester,
  ) async {
    final gate = Completer<void>();
    exportService.gate = gate;

    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pump();

    // The native save panel is modal at the OS level; no Flutter modal route
    // may be up while it is open.
    expect(find.text('Exporting...'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Dive exported successfully'), findsOneWidget);
  });

  testWidgets('a failed export reports the error', (tester) async {
    exportService.failure = StateError('disk full');
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Share');

    expect(find.textContaining('disk full'), findsOneWidget);
    expect(find.text('Dive exported successfully'), findsNothing);
  });
}
