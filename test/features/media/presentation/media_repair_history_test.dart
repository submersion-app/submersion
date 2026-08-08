import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_history_view.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

RepairLogEntry logEntry(
  String id, {
  required RepairLogAction action,
  required RepairLogSource source,
  String? newValue,
  DateTime? at,
}) => RepairLogEntry(
  id: id,
  mediaId: 'media-$id',
  batchId: 'batch-1',
  occurredAt: at ?? DateTime(2026, 8, 6, 15, 4),
  action: action,
  oldValue: '/old/$id.jpg',
  newValue: newValue,
  source: source,
);

void main() {
  Widget host(List<RepairLogEntry> entries) {
    return ProviderScope(
      overrides: [repairHistoryProvider.overrideWith((ref) async => entries)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaRepairHistoryView(),
      ),
    );
  }

  testWidgets('empty history shows the localized empty state', (tester) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();

    expect(find.text('Repair history'), findsOneWidget);
    expect(find.text('No repairs yet'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('every action kind renders its own label and icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        logEntry(
          'a',
          action: RepairLogAction.relink,
          source: RepairLogSource.folder,
          newValue: '/nas/Dives/a.jpg',
        ),
        logEntry(
          'b',
          action: RepairLogAction.cloudBacked,
          source: RepairLogSource.store,
        ),
        logEntry(
          'c',
          action: RepairLogAction.autoRelink,
          source: RepairLogSource.watcher,
          newValue: '/nas/Dives/c.jpg',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Re-linked'), findsOneWidget);
    expect(find.text('Cloud-backed'), findsOneWidget);
    expect(find.text('Auto re-linked'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high_outlined), findsOneWidget);
  });

  testWidgets('a row shows the new value, timestamp, and source', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        logEntry(
          'a',
          action: RepairLogAction.autoRelink,
          source: RepairLogSource.watcher,
          newValue: '/nas/Dives/a.jpg',
          at: DateTime(2026, 8, 6, 15, 4),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('/nas/Dives/a.jpg'), findsOneWidget);
    // intl separates the time from the meridiem with U+202F (narrow no-break
    // space), not an ordinary space.
    expect(
      find.text('Aug 6, 2026 3:04\u202FPM via watched folders'),
      findsOneWidget,
    );
  });

  testWidgets('a row with no new value falls back to the media id', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        logEntry(
          'b',
          action: RepairLogAction.cloudBacked,
          source: RepairLogSource.store,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('media-b'), findsOneWidget);
    expect(find.textContaining('via cloud media store'), findsOneWidget);
  });

  testWidgets('rows render in the order the repository returned them', (
    tester,
  ) async {
    await tester.pumpWidget(
      host([
        logEntry(
          'newest',
          action: RepairLogAction.relink,
          source: RepairLogSource.folder,
          newValue: '/newest.jpg',
          at: DateTime(2026, 8, 6),
        ),
        logEntry(
          'oldest',
          action: RepairLogAction.relink,
          source: RepairLogSource.folder,
          newValue: '/oldest.jpg',
          at: DateTime(2026, 1, 1),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final newest = tester.getTopLeft(find.text('/newest.jpg'));
    final oldest = tester.getTopLeft(find.text('/oldest.jpg'));
    expect(newest.dy, lessThan(oldest.dy));
  });
}
