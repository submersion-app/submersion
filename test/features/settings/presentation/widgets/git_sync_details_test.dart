import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_reset_records.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/git_sync_details.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _config = GitConfig(
  repoUrl: 'https://github.com/you/dive-log',
  username: 'you',
  token: 't',
);

void main() {
  late GitResetRecords records;

  setUp(() {
    records = GitResetRecords();
    addTearDown(records.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gitConfigProvider.overrideWith((ref) async => _config),
          gitResetRecordsProvider.overrideWithValue(records),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GitSyncDetails()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a refused reset shows while the page stays open', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('would not reset the history'), findsNothing);

    records.noteRefused(gitNaturalKey(_config), refused: true);
    await tester.pumpAndSettle();

    expect(find.textContaining('would not reset the history'), findsOneWidget);
  });

  testWidgets('a reset shows while the page stays open', (tester) async {
    await pump(tester);
    expect(find.textContaining('History last reset'), findsNothing);

    records.noteReset(gitNaturalKey(_config), DateTime.utc(2026, 10, 19, 12));
    await tester.pumpAndSettle();

    expect(find.textContaining('History last reset'), findsOneWidget);
  });

  testWidgets('a reset that clears a refusal removes the warning', (
    tester,
  ) async {
    records.noteRefused(gitNaturalKey(_config), refused: true);
    await pump(tester);
    expect(find.textContaining('would not reset the history'), findsOneWidget);

    records.noteRefused(gitNaturalKey(_config), refused: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('would not reset the history'), findsNothing);
  });

  testWidgets('another repository changing leaves this one alone', (
    tester,
  ) async {
    await pump(tester);

    records.noteRefused('https://example.com/other|main', refused: true);
    await tester.pumpAndSettle();

    expect(find.textContaining('would not reset the history'), findsNothing);
  });
}
