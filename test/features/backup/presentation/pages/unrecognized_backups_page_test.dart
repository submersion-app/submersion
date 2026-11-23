import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backups_directory_access.dart';
import 'package:submersion/features/backup/data/services/orphaned_backup_scan.dart';
import 'package:submersion/features/backup/data/services/unrecognized_backup_service.dart';
import 'package:submersion/features/backup/presentation/pages/unrecognized_backups_page.dart';
import 'package:submersion/features/backup/presentation/providers/unrecognized_backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Stands in for the filesystem.
///
/// Both real methods do `dart:io` work, and an await on real I/O inside
/// `testWidgets` never completes under FakeAsync, so the run would hang with no
/// output rather than fail. The real service has its own tests against a temp
/// directory.
class _FakeService extends UnrecognizedBackupService {
  _FakeService({this.freed = 0, this.onReclaim})
    : super(
        access: BackupsDirectoryAccess(
          configuredLocation: () async => null,
          acquireLease: () async =>
              throw StateError('the fake never reaches the filesystem'),
        ),
        knownPaths: () async => const {},
        thisDeviceId: () async => '',
      );

  final int freed;
  final void Function()? onReclaim;
  final reclaimed = <UnrecognizedBackup>[];

  @override
  Future<int> reclaim(Iterable<UnrecognizedBackup> selection) async {
    reclaimed.addAll(selection);
    onReclaim?.call();
    return freed;
  }
}

void main() {
  UnrecognizedBackup entry({
    required String name,
    int bytes = 1024,
    BackupOwnership ownership = BackupOwnership.thisDevice,
    String? note,
    bool inAppPrivateFolder = false,
  }) => UnrecognizedBackup(
    path: '/backups/$name',
    sizeBytes: bytes,
    modified: DateTime(2026, 9, 1, 12),
    ownership: ownership,
    note: note,
    inAppPrivateFolder: inAppPrivateFolder,
  );

  Widget harness({
    required Future<List<UnrecognizedBackup>?> Function() entries,
    UnrecognizedBackupService? service,
  }) => ProviderScope(
    overrides: [
      // The page reads settingsProvider for the diver's date format; the real
      // notifier reaches for a DatabaseService this harness never starts.
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      unrecognizedBackupsProvider.overrideWith((ref) => entries()),
      if (service != null)
        unrecognizedBackupServiceProvider.overrideWithValue(service),
    ],
    child: const MaterialApp(
      // Pinned: flutter_test forwards the host machine's locale list, and the
      // English assertions below would find nothing on a translated build.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UnrecognizedBackupsPage(),
    ),
  );

  testWidgets('a file with a note shows it', (tester) async {
    await tester.pumpWidget(
      harness(
        entries: () async => [entry(name: 'a.db', note: 'Old laptop backup')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old laptop backup'), findsOneWidget);
  });

  testWidgets('lists every unrecognized file with its size', (tester) async {
    await tester.pumpWidget(
      harness(
        entries: () async => [
          entry(name: 'a.db', bytes: 2048),
          entry(name: 'b.db', bytes: 1024),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('a.db'), findsOneWidget);
    expect(find.text('b.db'), findsOneWidget);
    expect(find.textContaining('2.0 KB'), findsWidgets);
  });

  testWidgets('only a file this device wrote can be selected', (tester) async {
    await tester.pumpWidget(
      harness(
        entries: () async => [
          entry(name: 'mine.db'),
          entry(name: 'theirs.db', ownership: BackupOwnership.otherDevice),
          entry(name: 'legacy.db', ownership: BackupOwnership.unattributed),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Another device'), findsOneWidget);
    expect(find.text('Unknown device'), findsOneWidget);
  });

  testWidgets('the delete action stays disabled until something is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(entries: () async => [entry(name: 'a.db')]),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('confirming deletes the selected files and reports bytes freed', (
    tester,
  ) async {
    var listed = [
      entry(name: 'mine.db', bytes: 2048),
      entry(name: 'theirs.db', ownership: BackupOwnership.otherDevice),
    ];
    final service = _FakeService(
      freed: 2048,
      onReclaim: () => listed = [
        entry(name: 'theirs.db', ownership: BackupOwnership.otherDevice),
      ],
    );

    await tester.pumpWidget(
      harness(entries: () async => listed, service: service),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.reclaimed.map((e) => e.filename), ['mine.db']);
    expect(find.textContaining('2.0 KB'), findsWidgets);
    expect(find.text('mine.db'), findsNothing);
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    final service = _FakeService();

    await tester.pumpWidget(
      harness(
        entries: () async => [entry(name: 'mine.db')],
        service: service,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(service.reclaimed, isEmpty);
    expect(find.text('mine.db'), findsOneWidget);
  });

  testWidgets('an empty scan says so rather than showing a bare list', (
    tester,
  ) async {
    await tester.pumpWidget(harness(entries: () async => []));
    await tester.pumpAndSettle();

    expect(find.textContaining('No unrecognized'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a failed scan reports the failure, not an empty folder', (
    tester,
  ) async {
    // The difference matters: "nothing to clean up" and "the folder could not
    // be read" look identical on an empty list, and only one of them means the
    // user has nothing left to do.
    await tester.pumpWidget(
      harness(entries: () async => throw const FileSystemException('denied')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not read'), findsOneWidget);
    expect(find.textContaining('No unrecognized'), findsNothing);
  });

  testWidgets('a folder that cannot be listed is not reported as clean', (
    tester,
  ) async {
    // An Android SAF location is a content:// tree URI with no directory to
    // enumerate. Rendering that as the empty state would tell the user there
    // is nothing to reclaim when nothing was ever looked at.
    await tester.pumpWidget(harness(entries: () async => null));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot list'), findsOneWidget);
    expect(find.textContaining('No unrecognized'), findsNothing);
  });

  testWidgets('a tick is dropped when the file stops being this device\'s', (
    tester,
  ) async {
    // A sync reset changes the device id, so the next scan classifies the same
    // file as another device's. Pruning only paths that VANISHED leaves this
    // one ticked: the bar counts a file whose tile now shows "Another device"
    // and no checkbox, and confirming would report "Freed 0 B" after the
    // service correctly refused it.
    var listed = [entry(name: 'mine.db')];

    await tester.pumpWidget(harness(entries: () async => listed));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    listed = [entry(name: 'mine.db', ownership: BackupOwnership.otherDevice)];
    ProviderScope.containerOf(
      tester.element(find.byType(UnrecognizedBackupsPage)),
    ).invalidate(unrecognizedBackupsProvider);
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  group('issue #4973', () {
    // A real name, so the device tag has its production length.
    final longName = buildBackupFilename(
      timestamp: '2026-11-20_174512',
      deviceId: '9f8e7d6c-1111-2222-3333-444455556666',
    );

    // A common 360 dp wide Android phone.
    void phoneSized(WidgetTester tester) {
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    RenderParagraph nameParagraph(WidgetTester tester) => tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .firstWhere(
          (paragraph) => paragraph.text.toPlainText().contains('submersion_'),
        );

    /// The offsets at which a new line starts, found where the caret's
    /// vertical position steps down. RenderParagraph exposes no line metrics.
    List<int> lineStarts(RenderParagraph paragraph) {
      final length = paragraph.text.toPlainText().length;
      double top(int offset) => paragraph
          .getOffsetForCaret(TextPosition(offset: offset), Rect.zero)
          .dy;
      return [
        for (var offset = 1; offset < length; offset++)
          if (top(offset) > top(offset - 1)) offset,
      ];
    }

    testWidgets('the full filename is readable at phone width', (tester) async {
      phoneSized(tester);
      await tester.pumpWidget(
        harness(
          entries: () async => [
            entry(name: longName, ownership: BackupOwnership.otherDevice),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = nameParagraph(tester);
      // Every character is there, only with break opportunities added.
      expect(paragraph.text.toPlainText().replaceAll('\u200B', ''), longName);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.overflow, isNot(TextOverflow.ellipsis));
      expect(lineStarts(paragraph), isNotEmpty, reason: 'it wraps instead');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the name breaks after an underscore wherever it fits', (
      tester,
    ) async {
      phoneSized(tester);
      await tester.pumpWidget(
        harness(entries: () async => [entry(name: longName)]),
      );
      await tester.pumpAndSettle();

      final paragraph = nameParagraph(tester);
      final text = paragraph.text.toPlainText();
      final starts = lineStarts(paragraph);
      expect(starts, isNotEmpty, reason: 'should wrap on a phone');

      // The width the segment from [from] to [to] would need on one line.
      double widthOf(int from, int to) => paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: from, extentOffset: to),
          )
          .fold(0.0, (sum, box) => sum + box.right - box.left);

      // Each line starts just after an underscore, so no segment such as the
      // timestamp or the device tag is split in two. The one exception is a
      // segment wider than the whole line, which no layout can keep whole:
      // the test font draws every glyph as a full square, so the 16-digit
      // device tag is that wide here, though a real phone font fits it.
      var atBoundaries = 0;
      for (final start in starts) {
        final segmentStart = text.lastIndexOf('\u200B', start - 1) + 1;
        if (segmentStart == start) {
          atBoundaries++;
          continue;
        }
        final next = text.indexOf('\u200B', start);
        final segmentEnd = next == -1 ? text.length : next;
        expect(
          widthOf(segmentStart, segmentEnd),
          greaterThan(paragraph.size.width),
          reason:
              'line broke mid-segment after '
              '"${text.substring(0, start).replaceAll('\u200B', '')}"',
        );
      }
      // Without break opportunities the whole name is one segment wider than
      // a line, and every break above would pass as unavoidable.
      expect(atBoundaries, greaterThan(0));
    });

    testWidgets('in the private folder another device\'s file is selectable', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          entries: () async => [
            entry(
              name: 'theirs.db',
              ownership: BackupOwnership.otherDevice,
              inAppPrivateFolder: true,
            ),
            entry(
              name: 'legacy.db',
              ownership: BackupOwnership.unattributed,
              inAppPrivateFolder: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNWidgets(2));
      // Still labelled, so the diver knows what they are choosing.
      expect(find.text('Another device'), findsOneWidget);
      expect(find.text('Unknown device'), findsOneWidget);
      expect(find.textContaining('private to Submersion'), findsOneWidget);
    });

    testWidgets('a shared folder keeps the original explanation', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(entries: () async => [entry(name: 'mine.db')]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('private to Submersion'), findsNothing);
      expect(
        find.textContaining('Only a file this device wrote'),
        findsOneWidget,
      );
    });

    testWidgets('deleting another device\'s file warns more strongly', (
      tester,
    ) async {
      final service = _FakeService(freed: 1024);
      await tester.pumpWidget(
        harness(
          entries: () async => [
            entry(
              name: 'theirs.db',
              ownership: BackupOwnership.otherDevice,
              inAppPrivateFolder: true,
            ),
          ],
          service: service,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('another device or an earlier'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(service.reclaimed.map((e) => e.filename), ['theirs.db']);
    });

    testWidgets('deleting only this device\'s files keeps the plain warning', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          entries: () async => [
            entry(name: 'mine.db', inAppPrivateFolder: true),
          ],
          service: _FakeService(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('permanently deleted'), findsOneWidget);
      expect(find.textContaining('another device or an earlier'), findsNothing);
    });
  });
}
