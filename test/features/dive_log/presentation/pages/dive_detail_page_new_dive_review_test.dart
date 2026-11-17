import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_new_dive_harness.dart';
import 'dive_detail_page_unlock_harness.dart';

/// Holds the buddy question until [gate] opens, so a test can look at the
/// page between the create and its moving on.
class _GatedMirror implements DiveMirrorService {
  _GatedMirror(this.gate);

  final Completer<void> gate;

  @override
  Future<List<MirrorCandidate>> candidates(String diveId) async {
    await gate.future;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Copies a scanned page into [dir] as the real service would, or fails.
class _FakeImport implements MediaImportService {
  _FakeImport(this.dir, {this.fail = false, this.firstGate});

  final Directory dir;
  final bool fail;

  /// Holds the first copy until it opens, as a large file would.
  final Completer<void>? firstGate;
  final copies = <String>[];
  var _calls = 0;

  @override
  Future<PreparedMedia> prepareLocalFileForDive({
    required File sourceFile,
    required String diveId,
    DateTime? takenAt,
    double? latitude,
    double? longitude,
    String subdirectory = kScannedLogsSubdirectory,
  }) async {
    if (fail) throw const FileSystemException('gone');
    final n = _calls++;
    if (n == 0) await firstGate?.future;
    final copy = await sourceFile.copy(p.join(dir.path, 'copy_$n.jpg'));
    copies.add(copy.path);
    final now = DateTime.utc(2026);
    return (
      item: MediaItem(
        id: 'scan',
        diveId: diveId,
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: copy.path,
        takenAt: takenAt ?? now,
        createdAt: now,
        updatedAt: now,
      ),
      enrichment: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// What the whole-branch review of plan 8 found (issue #4527).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  late Directory dir;
  late File scan;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('new_dive_review');
    scan = File(p.join(dir.path, 'page.jpg'))
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> typeNote(WidgetTester tester, String text) async {
    final field = find.descendant(
      of: find.byType(DiveNotesCardEditor),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await settle(tester);
  }

  testWidgets('a new dive page takes the unlock it needs by default', (
    tester,
  ) async {
    expect(const DiveDetailPage.newDive().unlockEditing, isTrue);
  });

  testWidgets('between the create and moving on, the page takes no input', (
    tester,
  ) async {
    final gate = Completer<void>();
    final page = await pumpNewDivePage(
      tester,
      shortcuts: true,
      extra: [diveMirrorServiceProvider.overrideWithValue(_GatedMirror(gate))],
    );
    await typeNote(tester, 'First dive');
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(page.save.creates, hasLength(1));
    expect(location(page.router), '/home/new');

    // The created dive shows locked; its lock does nothing yet.
    final lock = find.byTooltip('Unlock to edit');
    expect(lock, findsOneWidget);
    await tester.tap(lock, warnIfMissed: false);
    await settle(tester);
    expect(newDiveController(tester).isUnlocked, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(location(page.router), '/home/new');

    gate.complete();
    await settle(tester);
    expect(page.save.creates, hasLength(1));
    expect(location(page.router), '/dives/${page.save.creates.single.dive.id}');
  });

  testWidgets('a sitting ended in place opens a fresh new dive', (
    tester,
  ) async {
    // As the pane's + pressed again: the guard asks, Discard ends the
    // sitting, and the pane stays on the same new-dive page.
    await pumpNewDivePage(tester, embedded: true);
    await typeNote(tester, 'Wall');
    final guard = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).read(appExitGuardProvider);

    final leaving = guard.mayLeave();
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(await leaving, isTrue);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
    }

    final controller = newDiveController(tester);
    expect(controller.isUnlocked, isTrue);
    expect(controller.isDirty, isFalse);
    expect(controller.openCardIds, contains(diveHeaderCardId));
    expect(find.text('Wall'), findsNothing);
  });

  testWidgets('Cancel removes the scanned page copied for the dive', (
    tester,
  ) async {
    final import = _FakeImport(dir);
    await pumpNewDivePage(
      tester,
      request: NewDiveRequest(prefill: DivePrefill(photoPath: scan.path)),
      extra: [mediaImportServiceProvider.overrideWithValue(import)],
    );
    expect(import.copies, hasLength(1));
    expect(File(import.copies.single).existsSync(), isTrue);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(File(import.copies.single).existsSync(), isFalse);
    expect(scan.existsSync(), isTrue);
  });

  testWidgets('a scanned page that cannot be held is said', (tester) async {
    await pumpNewDivePage(
      tester,
      request: NewDiveRequest(prefill: DivePrefill(photoPath: scan.path)),
      extra: [
        mediaImportServiceProvider.overrideWithValue(
          _FakeImport(dir, fail: true),
        ),
      ],
    );
    expect(
      find.text('The scanned page could not be attached to this dive'),
      findsOneWidget,
    );
  });

  testWidgets('a scanned page lays out the Media card open', (tester) async {
    // The Media card a scan fills is laid out open (plan 8).
    await pumpNewDivePage(
      tester,
      request: NewDiveRequest(prefill: DivePrefill(photoPath: scan.path)),
      extra: [mediaImportServiceProvider.overrideWithValue(_FakeImport(dir))],
    );
    expect(
      newDiveController(tester).openCardIds,
      contains(DiveDetailSectionId.media.name),
    );
  });

  testWidgets('a copy that lands after its sitting ended removes only itself', (
    tester,
  ) async {
    final gate = Completer<void>();
    final import = _FakeImport(dir, firstGate: gate);
    await pumpNewDivePage(
      tester,
      embedded: true,
      request: NewDiveRequest(prefill: DivePrefill(photoPath: scan.path)),
      extra: [mediaImportServiceProvider.overrideWithValue(import)],
    );
    await typeNote(tester, 'Wall');
    final guard = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).read(appExitGuardProvider);
    final leaving = guard.mayLeave();
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);
    expect(await leaving, isTrue);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
    }
    // The fresh sitting has copied the page again.
    expect(import.copies, hasLength(1));
    final fresh = import.copies.single;

    gate.complete();
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
    }

    expect(import.copies, hasLength(2));
    expect(File(import.copies.last).existsSync(), isFalse);
    expect(File(fresh).existsSync(), isTrue);
  });
}
