import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/orphaned_backup_scan.dart';
import 'package:submersion/features/backup/presentation/providers/unrecognized_backup_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/unrecognized_backups_notice.dart';
import 'package:submersion/features/settings/presentation/pages/storage_usage_page.dart';
import 'package:submersion/features/settings/presentation/providers/storage_usage_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  /// The page is a lazy ListView, so a short surface builds only the rows that
  /// fit. Every test here is about what the page reports rather than about
  /// scrolling, so the surface is made tall enough for all fifteen rows.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Sizes are thunks rather than futures so an error case is constructed only
  /// once the provider is listening. A `Future.error` built eagerly in a map
  /// literal has no listener yet and the zone reports it as unhandled, failing
  /// the test before the page ever renders it.
  Widget harness({
    required Map<String, Future<int?> Function()> sizes,
    Future<List<UnrecognizedBackup>?> Function()? unrecognized,
  }) {
    return ProviderScope(
      overrides: [
        storageCategorySizeProvider.overrideWith(
          (ref, id) => sizes[id]?.call() ?? Future<int?>.value(0),
        ),
        // The backups group carries a notice fed by a filesystem scan. Left
        // live it would reach SharedPreferences and the sync database, so
        // every test here states what the scan found, defaulting to nothing.
        unrecognizedBackupsProvider.overrideWith(
          (ref) => unrecognized?.call() ?? Future.value(const []),
        ),
      ],
      child: const MaterialApp(
        // Pinned: the assertions match English strings.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StorageUsagePage(),
      ),
    );
  }

  /// Scoped to a row, because the total header can render the same byte string
  /// as a row and an unscoped finder would match it instead.
  Finder rowText(String text) => find.descendant(
    of: find.byType(StorageUsageRow),
    matching: find.text(text),
  );

  testWidgets('renders a row for every category', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(harness(sizes: {}));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StorageUsagePage)),
    );
    final expected = container.read(storageCategoriesProvider).length;

    expect(expected, 15);
    expect(find.byType(StorageUsageRow), findsNWidgets(expected));
  });

  testWidgets('shows the raw imported data group and its row', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {StorageCategoryId.importedFiles: () => Future<int?>.value(0)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raw imported data'), findsOneWidget);
    expect(rowText('Imported logbook files'), findsOneWidget);
  });

  testWidgets('shows a formatted size once a category resolves', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {StorageCategoryId.database: () => Future<int?>.value(1536)},
      ),
    );
    await tester.pumpAndSettle();

    expect(rowText('1.5 KB'), findsOneWidget);
  });

  testWidgets('a null measurement reads as unavailable, never as zero', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {StorageCategoryId.backups: () => Future<int?>.value(null)},
      ),
    );
    await tester.pumpAndSettle();

    expect(rowText('Not available'), findsOneWidget);
  });

  testWidgets(
    'a failing category errors on its own row and its siblings still resolve',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        harness(
          sizes: {
            StorageCategoryId.networkImages: () =>
                Future<int?>.error(const FileSystemException('denied')),
            StorageCategoryId.database: () => Future<int?>.value(2048),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(rowText('Could not measure'), findsOneWidget);
      expect(rowText('2.0 KB'), findsOneWidget);
    },
  );

  testWidgets('the total sums only the categories that resolved', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.database: () => Future<int?>.value(1024),
          StorageCategoryId.localCache: () => Future<int?>.value(1024),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Each contributing row reads 1.0 KB, so a lone 2.0 KB is the total.
    expect(rowText('1.0 KB'), findsNWidgets(2));
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(rowText('2.0 KB'), findsNothing);
  });

  testWidgets('the header stays partial when a category errored', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.networkImages: () =>
              Future<int?>.error(const FileSystemException('denied')),
        },
      ),
    );
    await tester.pumpAndSettle();

    // Nothing is loading any more, but the sum is still short by whatever the
    // failed category holds, so calling it the total would be a false claim.
    expect(find.text('Total so far'), findsOneWidget);
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('the header stays partial when a category is unmeasurable', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {StorageCategoryId.backups: () => Future<int?>.value(null)},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total so far'), findsOneWidget);
    expect(find.text('Total'), findsNothing);
  });

  testWidgets('the header reads as final only when every category counted', (
    tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(harness(sizes: {}));
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Total so far'), findsNothing);
  });

  testWidgets('an errored category is left out of the total', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.database: () => Future<int?>.value(1024),
          StorageCategoryId.networkImages: () =>
              Future<int?>.error(const FileSystemException('denied')),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1.0 KB'), findsNWidgets(2));
  });

  testWidgets('a row does not overflow at a narrow width', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      harness(
        sizes: {
          StorageCategoryId.mediaCacheOriginals: () =>
              Future<int?>.value(5 * 1024 * 1024 * 1024),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('unrecognized backups notice', () {
    UnrecognizedBackup forgotten({int bytes = 1024}) => UnrecognizedBackup(
      path: '/backups/submersion_backup_2026-09-01_1200__d$bytes.db',
      sizeBytes: bytes,
      modified: DateTime(2026, 9, 1),
      ownership: BackupOwnership.thisDevice,
    );

    testWidgets('surfaces files the backup history has lost track of', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        harness(
          sizes: {},
          unrecognized: () async => [
            forgotten(bytes: 1024),
            forgotten(bytes: 3072),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 files not in your backup history'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(UnrecognizedBackupsNotice),
          matching: find.text('4.0 KB'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('stays out of the way when the scan finds nothing', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(harness(sizes: {}, unrecognized: () async => []));
      await tester.pumpAndSettle();

      expect(find.byType(UnrecognizedBackupsNotice), findsOneWidget);
      expect(find.textContaining('not in your backup history'), findsNothing);
    });

    testWidgets('says nothing while the scan is still running', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        harness(
          sizes: {},
          unrecognized: () => Completer<List<UnrecognizedBackup>?>().future,
        ),
      );
      await tester.pump();

      expect(find.textContaining('not in your backup history'), findsNothing);
    });

    testWidgets('a failed scan does not claim the folder is clean', (
      tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        harness(
          sizes: {},
          unrecognized: () async => throw const FileSystemException('denied'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('not in your backup history'), findsNothing);
    });
  });
}
