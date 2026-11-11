// Issue #4465: Settings > Data tools offers the relink of downloaded data
// sources that lost their dive computer, as a one-tap repair.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/relink_data_sources_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeRepository extends DiveComputerRepository {
  _FakeRepository({this.linked = 0, this.error});

  final int linked;
  final Object? error;
  int calls = 0;

  @override
  Future<int> relinkOrphanedSources() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return linked;
  }
}

void main() {
  Future<void> pumpTile(WidgetTester tester, _FakeRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [diveComputerRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RelinkDataSourcesTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Relink data sources'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Relink'));
    await tester.pumpAndSettle();
  }

  testWidgets('relinks after the diver confirms and reports the count', (
    tester,
  ) async {
    final repo = _FakeRepository(linked: 3);
    await pumpTile(tester, repo);

    await confirm(tester);

    expect(repo.calls, 1);
    expect(
      find.text('Linked 3 data sources to their dive computers'),
      findsOneWidget,
    );
  });

  testWidgets('says so when nothing could be matched', (tester) async {
    final repo = _FakeRepository();
    await pumpTile(tester, repo);

    await confirm(tester);

    expect(
      find.text('No unlinked data sources matched a dive computer'),
      findsOneWidget,
    );
  });

  testWidgets('does nothing when the diver cancels', (tester) async {
    final repo = _FakeRepository(linked: 3);
    await pumpTile(tester, repo);

    await tester.tap(find.text('Relink data sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports a failure', (tester) async {
    final repo = _FakeRepository(error: StateError('disk full'));
    await pumpTile(tester, repo);

    await confirm(tester);

    expect(
      find.textContaining('Could not relink data sources'),
      findsOneWidget,
    );
  });
}
