import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/data/services/backup_origin.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_history_tile.dart';
import 'package:submersion/features/backup/presentation/widgets/pre_migration_badge.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

BackupRecord _manual({
  bool pinned = false,
  bool isAutomatic = false,
  int? diveCount = 5,
  int? siteCount = 3,
  String? note,
}) {
  return BackupRecord(
    id: 'm',
    filename: 'manual.db',
    timestamp: DateTime(2026, 4, 12, 8, 12),
    sizeBytes: 2048,
    location: BackupLocation.local,
    localPath: '/tmp/manual.db',
    pinned: pinned,
    isAutomatic: isAutomatic,
    diveCount: diveCount,
    siteCount: siteCount,
    note: note,
  );
}

BackupRecord _preDowngrade() {
  return BackupRecord(
    id: 'kept',
    filename: 'newer.db',
    timestamp: DateTime(2026, 9, 5, 8, 12),
    sizeBytes: 4096,
    location: BackupLocation.local,
    localPath: '/tmp/newer.db',
    type: BackupType.preDowngrade,
    appVersion: '1.8.0.7300',
    // No toSchemaVersion: nothing was migrated, this is where the file
    // stopped.
    fromSchemaVersion: 191,
    pinned: true,
  );
}

BackupRecord _preMigration({
  int? fromVersion = 63,
  int? toVersion = 64,
  bool pinned = false,
}) {
  return BackupRecord(
    id: 'pre',
    filename: 'pre.db',
    timestamp: DateTime(2026, 4, 12, 8, 12),
    sizeBytes: 4096,
    location: BackupLocation.local,
    localPath: '/tmp/pre.db',
    type: BackupType.preMigration,
    appVersion: '1.5.9.1000',
    fromSchemaVersion: fromVersion,
    toSchemaVersion: toVersion,
    pinned: pinned,
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    // The tile watches settingsProvider for the diver's date format. The real
    // notifier reaches for DiverSettingsRepository and a DatabaseService this
    // harness never starts, so stand in with the shared mock.
    overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
    child: MaterialApp(
      // Pinned: flutter_test forwards the HOST machine's locale list rather
      // than a fixed en_US, and this app supports 11 locales, so an unpinned
      // MaterialApp renders a translated UI on a non-English machine and
      // every English assertion below finds nothing. CI stays green because
      // its runners are en_US, so this would fail only for a contributor.
      // Load-bearing since the manual subtitle moved to l10n: it used to be a
      // Dart string literal that rendered English whatever the locale.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('a backup pinned on another device shows a locked pin (#3503)', (
    tester,
  ) async {
    var toggled = false;
    await tester.pumpWidget(
      _wrap(
        BackupHistoryTile(
          record: _manual().copyWith(pinnedOnAnotherDevice: true),
          leadingIcon: Icons.cloud_outlined,
          onPinToggle: () => toggled = true,
          onRestore: () {},
          onDelete: () {},
          shareSheetAvailable: true,
        ),
      ),
    );
    final button = find.widgetWithIcon(IconButton, Icons.push_pin);
    expect(button, findsOneWidget);
    expect(
      tester.widget<IconButton>(button).tooltip,
      'Pinned on another device',
    );
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    expect(toggled, isFalse);
  });

  group('BackupHistoryTile rendering', () {
    testWidgets('a noted backup shows its note above the counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(note: 'Before the Cozumel trip'),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.text('Before the Cozumel trip'), findsOneWidget);
      expect(find.textContaining('5 dives, 3 sites'), findsOneWidget);
      final noteY = tester.getTopLeft(find.text('Before the Cozumel trip')).dy;
      final countsY = tester.getTopLeft(find.textContaining('5 dives')).dy;
      expect(noteY, lessThan(countsY));
    });

    testWidgets('a backup without a note shows only the counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(
        find.byWidgetPredicate((w) => w is Text && w.maxLines == 2),
        findsNothing,
        reason: 'only a note line is capped at two lines',
      );
    });

    testWidgets('manual record shows dive/site counts + optional (auto)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(isAutomatic: true),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.textContaining('5 dives, 3 sites'), findsOneWidget);
      expect(find.textContaining(' (auto)'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
    });

    testWidgets('manual record without isAutomatic omits (auto) suffix', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(isAutomatic: false),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.textContaining(' (auto)'), findsNothing);
    });

    testWidgets('a single dive and site are not pluralised', (tester) async {
      // The subtitle went through the localisation layer to stop shipping
      // hard-coded English on a translated screen; a count of one is what
      // proves the plural forms are actually being selected rather than a
      // fixed string being interpolated.
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(diveCount: 1, siteCount: 1),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.textContaining('1 dive, 1 site'), findsOneWidget);
      expect(find.textContaining('1 dives'), findsNothing);
    });

    testWidgets('manual record null counts render as 0 dives, 0 sites', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(diveCount: null, siteCount: null),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.textContaining('0 dives, 0 sites'), findsOneWidget);
    });

    testWidgets('a cloud backup found without a record shows only its size', (
      tester,
    ) async {
      // Listed from the cloud folder after a fresh install (issue #3214): the
      // counts lived only in the lost record, so "0 dives" would be a lie.
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: BackupRecord(
              id: 'cloud:x',
              filename: 'submersion_backup_2026-03-14_093015.db',
              timestamp: DateTime(2026, 3, 14, 9, 30),
              sizeBytes: 2048,
              location: BackupLocation.cloud,
              cloudFileId: 'x',
            ),
            leadingIcon: Icons.cloud,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.text('In cloud storage (2.0 KB)'), findsOneWidget);
      expect(find.textContaining('dives'), findsNothing);
    });

    testWidgets('preDowngrade record names itself as the kept newer database', (
      tester,
    ) async {
      // Copied from a database this build had already left behind, so it
      // carries no dive or site counts and must not claim "0 dives".
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _preDowngrade(),
            leadingIcon: Icons.computer,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );

      expect(find.textContaining('Newer database'), findsOneWidget);
      expect(find.textContaining('dives'), findsNothing);
      // The schema badge belongs to a pre-migration pair; this record has no
      // toSchemaVersion, so there is no upgrade to name.
      expect(find.byType(PreMigrationBadge), findsNothing);
    });

    testWidgets(
      'preMigration record shows badge + pre-migration subtitle copy',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupHistoryTile(
              record: _preMigration(),
              leadingIcon: Icons.phone_android,
              onPinToggle: () {},
              onRestore: () {},
              onDelete: () {},
              shareSheetAvailable: true,
            ),
          ),
        );
        expect(find.byType(PreMigrationBadge), findsOneWidget);
        expect(find.text('v63 \u2192 v64'), findsOneWidget);
        expect(find.textContaining('Pre-migration backup'), findsOneWidget);
      },
    );

    testWidgets(
      'preMigration record with null schema versions hides the badge',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupHistoryTile(
              record: _preMigration(fromVersion: null, toVersion: null),
              leadingIcon: Icons.phone_android,
              onPinToggle: () {},
              onRestore: () {},
              onDelete: () {},
              shareSheetAvailable: true,
            ),
          ),
        );
        expect(find.byType(PreMigrationBadge), findsNothing);
        expect(find.textContaining('Pre-migration backup'), findsOneWidget);
      },
    );

    testWidgets('cloud leading icon is rendered', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.cloud,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud), findsOneWidget);
    });
  });

  group('BackupHistoryTile pin control', () {
    testWidgets('unpinned record shows outlined pin icon + Pin tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      expect(
        find.widgetWithIcon(IconButton, Icons.push_pin_outlined),
        findsOneWidget,
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.push_pin_outlined),
      );
      expect(button.tooltip, 'Pin backup');
    });

    testWidgets('pinned record shows filled pin icon + Unpin tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(pinned: true),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.push_pin),
      );
      expect(button.tooltip, 'Unpin backup');
    });

    testWidgets('tapping pin icon invokes onPinToggle', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () => taps++,
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('BackupHistoryTile popup menu', () {
    testWidgets('Restore menu item invokes onRestore', (tester) async {
      var restores = 0;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () => restores++,
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      expect(restores, 1);
    });

    testWidgets('Delete menu item invokes onDelete', (tester) async {
      var deletes = 0;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () => deletes++,
            shareSheetAvailable: true,
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      expect(deletes, 1);
    });
    testWidgets(
      'menu shows Share between Restore and Delete when a share sheet exists',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            BackupHistoryTile(
              record: _manual(),
              leadingIcon: Icons.phone_android,
              onPinToggle: () {},
              onRestore: () {},
              onShare: (_) {},
              onDelete: () {},
              shareSheetAvailable: true,
            ),
          ),
        );
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        final values = tester
            .widgetList<PopupMenuItem<String>>(
              find.byType(PopupMenuItem<String>),
            )
            .map((item) => item.value)
            .toList();
        expect(values, ['restore', 'share', 'delete']);
        expect(find.text('Share'), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
      },
    );

    testWidgets('menu shows Save a copy when no share sheet exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onShare: (_) {},
            onDelete: () {},
            shareSheetAvailable: false,
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Save a copy'), findsOneWidget);
      expect(find.byIcon(Icons.save_alt), findsOneWidget);
      expect(find.text('Share'), findsNothing);
    });

    testWidgets('Share item is disabled when onShare is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      final share = tester
          .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
          .singleWhere((item) => item.value == 'share');
      expect(share.enabled, isFalse);
    });

    testWidgets('choosing Share calls onShare with the tile context', (
      tester,
    ) async {
      // The iPad share popover anchors to this context, so it must be the
      // row's, not the list's.
      var shares = 0;
      BuildContext? shareContext;
      await tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: _manual(),
            leadingIcon: Icons.phone_android,
            onPinToggle: () {},
            onRestore: () {},
            onShare: (tileContext) {
              shares++;
              shareContext = tileContext;
            },
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.share));
      await tester.pumpAndSettle();
      expect(shares, 1);
      expect(shareContext!.widget, isA<BackupHistoryTile>());
    });
  });

  group('originating device (#3651)', () {
    Future<void> pumpTile(
      WidgetTester tester, {
      required BackupRecord record,
      BackupOrigin? origin,
    }) {
      return tester.pumpWidget(
        _wrap(
          BackupHistoryTile(
            record: record,
            origin: origin,
            leadingIcon: Icons.cloud,
            onPinToggle: () {},
            onRestore: () {},
            onDelete: () {},
            shareSheetAvailable: true,
          ),
        ),
      );
    }

    testWidgets('a backup made here ends its summary with This device', (
      tester,
    ) async {
      await pumpTile(
        tester,
        record: _manual(isAutomatic: true),
        origin: const BackupFromThisDevice(),
      );
      expect(
        find.text('5 dives, 3 sites - 2.0 KB (auto) \u00b7 This device'),
        findsOneWidget,
      );
    });

    testWidgets('a named peer backup ends its summary with that name', (
      tester,
    ) async {
      await pumpTile(
        tester,
        record: BackupRecord(
          id: 'cloud:x',
          filename: 'x.db',
          timestamp: DateTime(2026, 10, 27, 21, 2),
          sizeBytes: 2048,
          location: BackupLocation.cloud,
        ),
        origin: const BackupFromNamedDevice("Eric's MacBook"),
      );
      expect(
        find.text("In cloud storage (2.0 KB) \u00b7 Eric's MacBook"),
        findsOneWidget,
      );
    });

    testWidgets('an unnamed peer backup says Another device', (tester) async {
      await pumpTile(
        tester,
        record: _manual(),
        origin: const BackupFromAnotherDevice(),
      );
      expect(
        find.text('5 dives, 3 sites - 2.0 KB \u00b7 Another device'),
        findsOneWidget,
      );
    });

    testWidgets('a pre-migration backup names its device too', (tester) async {
      await pumpTile(
        tester,
        record: _preMigration(),
        origin: const BackupFromThisDevice(),
      );
      expect(
        find.text('Pre-migration backup - 4.0 KB \u00b7 This device'),
        findsOneWidget,
      );
    });

    testWidgets('the device stays on the summary line under a note', (
      tester,
    ) async {
      await pumpTile(
        tester,
        record: _manual(note: 'Before the Cozumel trip'),
        origin: const BackupFromThisDevice(),
      );
      expect(find.text('Before the Cozumel trip'), findsOneWidget);
      expect(
        find.text('5 dives, 3 sites - 2.0 KB \u00b7 This device'),
        findsOneWidget,
      );
    });

    testWidgets('a backup with no known origin shows no device', (
      tester,
    ) async {
      await pumpTile(tester, record: _manual());
      expect(find.text('5 dives, 3 sites - 2.0 KB'), findsOneWidget);
      expect(find.textContaining('\u00b7'), findsNothing);
    });
  });
}
