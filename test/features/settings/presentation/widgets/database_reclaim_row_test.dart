import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/compaction/database_compaction_prefs.dart';
import 'package:submersion/core/database/compaction/database_space.dart';
import 'package:submersion/features/settings/presentation/providers/database_reclaim_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/database_reclaim_row.dart';

import '../../../../helpers/test_app.dart';

const _mb = 1024 * 1024;

DatabaseSpace _space(int fileMb, int freeMb) => DatabaseSpace(
  pageSize: 4096,
  pageCount: fileMb * _mb ~/ 4096,
  freePages: freeMb * _mb ~/ 4096,
);

void main() {
  late DatabaseCompactionPrefs prefs;
  var quits = 0;

  setUp(() async {
    quits = 0;
    SharedPreferences.setMockInitialValues({});
    prefs = DatabaseCompactionPrefs(await SharedPreferences.getInstance());
  });

  Future<void> pumpRow(
    WidgetTester t, {
    Future<DatabaseSpace> Function()? space,
    bool desktop = false,
  }) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          databaseSpaceProvider.overrideWith(
            (ref) => space?.call() ?? Future.value(_space(400, 30)),
          ),
          databaseCompactionPrefsProvider.overrideWith((ref) async => prefs),
        ],
        child: DatabaseReclaimRow(
          isDesktop: desktop,
          quitOverride: () async => quits++,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('shows reclaimable space and schedules a compaction', (t) async {
    await pumpRow(t);
    expect(find.text('30 MB reclaimable'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Compact'));
    await t.pumpAndSettle();
    expect(find.text('Compact the database?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Compact'));
    await t.pumpAndSettle();
    expect(prefs.isRequested, isTrue);
    expect(find.text('Scheduled for next launch'), findsOneWidget);
  });

  testWidgets('cancelling the dialog schedules nothing', (t) async {
    await pumpRow(t);
    await t.tap(find.widgetWithText(TextButton, 'Compact'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(prefs.isRequested, isFalse);
  });

  testWidgets('a scheduled compaction can be withdrawn', (t) async {
    await prefs.request();
    await pumpRow(t);
    expect(find.text('Scheduled for next launch'), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(prefs.isRequested, isFalse);
    // Cancelling also holds automatic compaction off, so the app's own
    // check does not schedule it again at the next launch.
    expect(prefs.inBackoff, isTrue);
    expect(find.widgetWithText(TextButton, 'Compact'), findsOneWidget);
  });

  testWidgets('the manual action ignores a backoff', (t) async {
    await prefs.recordFailure();
    await pumpRow(t);
    expect(find.widgetWithText(TextButton, 'Compact'), findsOneWidget);
  });

  testWidgets('Quit now is offered on desktop only', (t) async {
    await prefs.request();
    await pumpRow(t);
    expect(find.text('Quit now'), findsNothing);
    await pumpRow(t, desktop: true);
    await t.tap(find.text('Quit now'));
    await t.pumpAndSettle();
    expect(quits, 1);
  });

  testWidgets('a scheduled compaction stays visible below 1 MB', (t) async {
    await prefs.request();
    await pumpRow(t, space: () async => _space(400, 0));
    expect(find.text('Scheduled for next launch'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('under 1 MB free shows nothing', (t) async {
    await pumpRow(t, space: () async => _space(400, 0));
    expect(find.textContaining('reclaimable'), findsNothing);
    expect(find.text('Compact'), findsNothing);
  });

  testWidgets('an unreadable database shows nothing', (t) async {
    await pumpRow(t, space: () async => throw StateError('closed'));
    expect(find.textContaining('reclaimable'), findsNothing);
  });
}
