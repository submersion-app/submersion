import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_copy_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _record = BackupRecord(
  id: 'r1',
  filename: 'submersion_backup_2026-10-27.db',
  timestamp: DateTime(2026, 10, 27, 19, 42),
  sizeBytes: 2048,
  location: BackupLocation.local,
  localPath: '/tmp/r1.db',
);

Widget _wrap(Widget child, {bool busy = false}) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    isBackupInProgressProvider.overrideWithValue(busy),
  ],
  child: MaterialApp(
    // Pinned so English assertions hold on a non-English host.
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  // The title's date is formatted by intl against Intl.defaultLocale, a
  // process global that MaterialApp.locale does not set. Pin it so the
  // English month holds on any host, and restore it so the global stays
  // contained.
  String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  testWidgets('shows the title with the formatted date and both actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: false,
          onSaveToFolder: () {},
          onShare: () {},
        ),
      ),
    );

    expect(find.textContaining('Backup from Oct 27, 2026'), findsOneWidget);
    expect(find.text('Save to a folder'), findsOneWidget);
    expect(find.text('Choose where to save the backup file'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Send via AirDrop, email, or other apps'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('hides Share when onShare is null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: false,
          onSaveToFolder: () {},
        ),
      ),
    );

    expect(find.text('Save to a folder'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('shows the device-locked line only when deviceLocked', (
    tester,
  ) async {
    const line =
        'This safety copy was taken from your protected database. It can '
        'only be restored on this device.';
    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: false,
          onSaveToFolder: () {},
        ),
      ),
    );
    expect(find.text(line), findsNothing);

    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: true,
          onSaveToFolder: () {},
        ),
      ),
    );
    expect(find.text(line), findsOneWidget);
  });

  testWidgets('tapping Save calls onSaveToFolder', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: false,
          onSaveToFolder: () => saved++,
          onShare: () {},
        ),
      ),
    );

    await tester.tap(find.text('Save to a folder'));
    expect(saved, 1);
  });

  testWidgets('tapping Share calls onShare', (tester) async {
    var shared = 0;
    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: false,
          onSaveToFolder: () {},
          onShare: () => shared++,
        ),
      ),
    );

    await tester.tap(find.text('Share'));
    expect(shared, 1);
  });

  testWidgets('show pops the sheet before calling back', (tester) async {
    var shared = 0;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => BackupCopySheet.show(
              context,
              record: _record,
              deviceLocked: false,
              onSaveToFolder: () {},
              onShare: () => shared++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(shared, 1);
    expect(find.byType(BackupCopySheet), findsNothing);
  });

  testWidgets('show pops the sheet before calling Save', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => BackupCopySheet.show(
              context,
              record: _record,
              deviceLocked: false,
              onSaveToFolder: () => saved++,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsNothing);
    await tester.tap(find.text('Save to a folder'));
    await tester.pumpAndSettle();

    expect(saved, 1);
    expect(find.byType(BackupCopySheet), findsNothing);
  });

  testWidgets('disables Save and Share while a backup operation runs', (
    tester,
  ) async {
    // Opened while idle, then a backup started: the notifier would ignore a
    // tap, so the sheet must not offer one.
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        BackupCopySheet(
          record: _record,
          deviceLocked: false,
          onSaveToFolder: () => taps++,
          onShare: () => taps++,
        ),
        busy: true,
      ),
    );

    await tester.tap(find.text('Save to a folder'));
    await tester.tap(find.text('Share'));

    expect(taps, 0);
  });
}
