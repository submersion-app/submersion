import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/pdf/diver_photo_loader.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

Dive _dive(String id, {DiveSite? site}) {
  final dt = DateTime(2026, 1, 1, id.hashCode % 12);
  return Dive(id: id, dateTime: dt, entryTime: dt, site: site);
}

/// Records which delivery each bulk export chose.
///
/// Only the six methods the bulk sheet can reach are implemented; anything
/// else throws via [noSuchMethod], so an unexpected call fails loudly rather
/// than silently returning null.
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

  /// The options the bulk sheet routed through, for assertions.
  PdfExportOptions? pdfOptions;

  /// The personalization the bulk sheet routed through, for assertions.
  Diver? pdfDiver;
  Uint8List? pdfDiverPhoto;

  Future<String?> _save(String label) async {
    calls.add('save:$label');
    await gate?.future;
    if (failure != null) throw failure!;
    return savePath;
  }

  @override
  Future<String> exportDivesToPdf(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    String title = 'Dive Logbook',
    Map<String, PdfProfileSeries>? profiles,
    List<Certification>? certifications,
    Diver? diver,
    Uint8List? diverPhoto,
  }) {
    pdfOptions = options;
    pdfDiver = diver;
    pdfDiverPhoto = diverPhoto;
    return _share('pdf');
  }

  @override
  Future<String?> saveDivesToPdfFile(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    String title = 'Dive Logbook',
    Map<String, PdfProfileSeries>? profiles,
    List<Certification>? certifications,
    Diver? diver,
    Uint8List? diverPhoto,
  }) {
    pdfOptions = options;
    pdfDiver = diver;
    pdfDiverPhoto = diverPhoto;
    return _save('pdf');
  }

  @override
  Future<String> exportDivesToCsv(List<Dive> dives) => _share('csv');

  @override
  Future<String?> saveDivesCsvToFile(List<Dive> dives) => _save('csv');

  @override
  Future<String> exportDivesToUddf(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    uddfSites = sites;
    return _share('uddf');
  }

  @override
  Future<String?> saveDivesToUddfFile(
    List<Dive> dives, {
    List<DiveSite>? sites,
    Map<String, Map<String, List<TankPressurePoint>>>? diveTankPressures,
  }) async {
    uddfSites = sites;
    return _save('uddf');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Returns no buddies; the junction load is exercised in repository tests.
class _FakeBuddyRepository extends BuddyRepository {
  @override
  Future<Map<String, List<BuddyWithRole>>> getBuddiesForDives(
    List<String> diveIds,
  ) async => const {};
}

class _FakeDiveRepository implements DiveRepository {
  _FakeDiveRepository(this.dives);
  final List<Dive> dives;

  @override
  Future<List<Dive>> getDivesByIds(List<String> ids) async =>
      dives.where((d) => ids.contains(d.id)).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadNextPage() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Finder _tile(String id) =>
    find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

void main() {
  late _RecordingExportService exportService;
  late List<Dive> dives;

  setUp(() {
    exportService = _RecordingExportService();
    dives = [
      _dive(
        'd1',
        site: const DiveSite(id: 's1', name: 'Aaa'),
      ),
      _dive('d2'),
    ];
  });

  /// Pumps the list, selects both dives, and opens the bulk export sheet.
  Future<void> pumpAndOpenExportSheet(
    WidgetTester tester, {
    Diver? diver,
    DiverPhotoLoader? photoLoader,
  }) async {
    final summaries = dives.map(DiveSummary.fromDive).toList();
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          paginatedDiveListProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(summaries),
          ),
          diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(dives)),
          exportServiceProvider.overrideWithValue(exportService),
          // The PDF route enriches the export with buddies, certifications
          // and the diver. Those reach a database widget tests do not have,
          // and the reads never settle, so stub them the way
          // getBaseOverrides stubs preDiveSessionForDiveProvider.
          buddyRepositoryProvider.overrideWithValue(_FakeBuddyRepository()),
          allCertificationsProvider.overrideWith((ref) async => const []),
          currentDiverProvider.overrideWith((ref) async => diver),
          // The real loader reads the file system, and a dart:io await never
          // completes inside testWidgets' FakeAsync zone.
          if (photoLoader != null)
            diverPhotoLoaderProvider.overrideWithValue(photoLoader),
        ],
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(_tile('d1'));
    await tester.pumpAndSettle();
    await tester.tap(_tile('d2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Selected'));
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
    // PDF now asks which template to use before asking where to put it, so a
    // bulk export is the same document a full-logbook export would produce.
    if (format == 'PDF Logbook') {
      await tester.tap(find.text('Export PDF'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(destination));
    await tester.pumpAndSettle();
  }

  testWidgets('bulk CSV export offers a save destination and uses it', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Save to File');

    expect(exportService.calls, ['save:csv']);
    expect(find.text('Exported 2 dives successfully'), findsOneWidget);
    // A completed export leaves selection mode.
    expect(find.text('2 selected'), findsNothing);
  });

  testWidgets('bulk CSV export can still share', (tester) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Share');

    expect(exportService.calls, ['share:csv']);
    expect(find.text('Exported 2 dives successfully'), findsOneWidget);
  });

  testWidgets('bulk PDF export honours the chosen destination', (tester) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'PDF Logbook', 'Save to File');

    expect(exportService.calls, ['save:pdf']);
  });

  testWidgets('bulk PDF export can still share', (tester) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'PDF Logbook', 'Share');

    expect(exportService.calls, ['share:pdf']);
    expect(
      exportService.pdfOptions?.template,
      PdfTemplate.detailed,
      reason: 'the picker default must reach the export service',
    );
  });

  group('diver portrait', () {
    // The bulk route passed `diver` but never `diverPhoto`, so the Detailed
    // front matter fell back to its placeholder frame on every path except
    // the settings export.
    final diver = Diver(
      id: 'me',
      name: 'Ada',
      photoPath: '/portraits/ada.jpg',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final portrait = Uint8List.fromList([9, 8, 7]);

    testWidgets('reaches the export service on share', (tester) async {
      await pumpAndOpenExportSheet(
        tester,
        diver: diver,
        photoLoader: (path) async =>
            path == '/portraits/ada.jpg' ? portrait : null,
      );
      await chooseFormatAndDestination(tester, 'PDF Logbook', 'Share');

      expect(exportService.pdfDiver?.id, 'me');
      expect(exportService.pdfDiverPhoto, portrait);
    });

    testWidgets('reaches the export service on save', (tester) async {
      await pumpAndOpenExportSheet(
        tester,
        diver: diver,
        photoLoader: (path) async => portrait,
      );
      await chooseFormatAndDestination(tester, 'PDF Logbook', 'Save to File');

      expect(exportService.pdfDiverPhoto, portrait);
    });

    testWidgets('an unreadable portrait still exports', (tester) async {
      await pumpAndOpenExportSheet(
        tester,
        diver: diver,
        photoLoader: (path) async => null,
      );
      await chooseFormatAndDestination(tester, 'PDF Logbook', 'Share');

      expect(exportService.calls, ['share:pdf']);
      expect(exportService.pdfDiverPhoto, isNull);
      expect(
        exportService.pdfDiver?.id,
        'me',
        reason: 'a missing portrait must not drop the diver as well',
      );
    });
  });

  testWidgets('dismissing the PDF template picker exports nothing', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('PDF Logbook'));
    await tester.pumpAndSettle();

    // Cancelling the picker is not a failure, it just stops the export.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(exportService.calls, isEmpty);
  });

  testWidgets('bulk UDDF export can still share, with sites', (tester) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'UDDF', 'Share');

    expect(exportService.calls, ['share:uddf']);
    expect(exportService.uddfSites?.map((s) => s.id), ['s1']);
  });

  testWidgets('bulk UDDF export passes the selected dives\' sites', (
    tester,
  ) async {
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'UDDF', 'Save to File');

    expect(exportService.calls, ['save:uddf']);
    expect(exportService.uddfSites?.map((s) => s.id), ['s1']);
  });

  testWidgets('cancelling the save panel is not reported as success', (
    tester,
  ) async {
    exportService.savePath = null;
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Save to File');

    expect(exportService.calls, ['save:csv']);
    expect(find.textContaining('successfully'), findsNothing);
    // Selection mode survives so the user can retry.
    expect(find.text('2 selected'), findsOneWidget);
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
    expect(find.textContaining('successfully'), findsNothing);
  });

  testWidgets('a failed export reports the error', (tester) async {
    exportService.failure = StateError('disk full');
    await pumpAndOpenExportSheet(tester);
    await chooseFormatAndDestination(tester, 'CSV', 'Save to File');

    expect(find.textContaining('disk full'), findsOneWidget);
    expect(find.textContaining('successfully'), findsNothing);
  });

  testWidgets('sharing shows progress, and a failure dismisses it', (
    tester,
  ) async {
    // Hold the delivery open so the progress dialog is observable, then fail
    // it: the catch must dismiss the dialog it left up.
    final gate = Completer<void>();
    exportService.gate = gate;
    exportService.failure = StateError('share broke');

    await pumpAndOpenExportSheet(tester);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(find.text('Exporting...'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Exporting...'), findsNothing);
    expect(find.textContaining('share broke'), findsOneWidget);
  });

  /// Same flow, but hosted the way master-detail layouts host it: inside a
  /// nested navigator whose only route is the list.
  ///
  /// [testApp] puts the list straight under `MaterialApp.home`, where the local
  /// and root navigators are one object, so it cannot catch a pop aimed at the
  /// wrong navigator. Here the progress dialog goes to the root navigator
  /// (`showDialog` defaults to `useRootNavigator: true`) while a bare
  /// `Navigator.of(context)` would resolve to the shell's, emptying it.
  Future<void> pumpInShellAndOpenExportSheet(WidgetTester tester) async {
    final summaries = dives.map(DiveSummary.fromDive).toList();
    final base = await getBaseOverrides();

    await tester.pumpWidget(
      testAppInShell(
        // Pinned so the English menu and dialog labels this test taps do not
        // depend on the host machine's locale, which flutter_test forwards.
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
          paginatedDiveListProvider.overrideWith(
            (ref) => _MockPaginatedNotifier(summaries),
          ),
          diveRepositoryProvider.overrideWithValue(_FakeDiveRepository(dives)),
          exportServiceProvider.overrideWithValue(exportService),
        ],
        child: const DiveListContent(showAppBar: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    await tester.tap(_tile('d1'));
    await tester.pumpAndSettle();
    await tester.tap(_tile('d2'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export Selected'));
    await tester.pumpAndSettle();
  }

  testWidgets('bulk UDDF share leaves the list on screen in master-detail', (
    tester,
  ) async {
    await pumpInShellAndOpenExportSheet(tester);
    await tester.tap(find.text('UDDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    // Not pumpAndSettle: a stranded progress dialog spins forever.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(exportService.calls, ['share:uddf']);
    expect(find.text('Exporting...'), findsNothing);
    expect(find.byType(DiveListContent), findsOneWidget);
  });

  testWidgets('bulk UDDF save leaves the list on screen in master-detail', (
    tester,
  ) async {
    await pumpInShellAndOpenExportSheet(tester);
    await tester.tap(find.text('UDDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save to File'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(exportService.calls, ['save:uddf']);
    expect(find.text('Exporting...'), findsNothing);
    expect(find.byType(DiveListContent), findsOneWidget);
  });

  testWidgets('a failed bulk export leaves the list on screen', (tester) async {
    exportService.failure = StateError('disk full');
    await pumpInShellAndOpenExportSheet(tester);
    await tester.tap(find.text('UDDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Exporting...'), findsNothing);
    expect(find.byType(DiveListContent), findsOneWidget);
  });
}
