import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/import_target_choice.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/computer_owner_notice.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// Issue #2050: the review step says whose computer this is and where the
// dives go, with a picker for this download only.

Diver _diver(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  final profiles = [_diver('bill', 'Bill'), _diver('mitchell', 'Mitchell')];

  Future<List<String>> pump(
    WidgetTester tester,
    ImportTargetChoice choice, {
    List<Diver>? divers,
    bool busy = false,
  }) async {
    final changes = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allDiversProvider.overrideWith((ref) async => divers ?? profiles),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ComputerOwnerNotice(
              choice: choice,
              onChanged: changes.add,
              busy: busy,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return changes;
  }

  testWidgets('names the owner as the destination by default', (tester) async {
    await pump(
      tester,
      const ImportTargetChoice(
        ownerDiverId: 'mitchell',
        chosenDiverId: 'mitchell',
      ),
    );

    expect(
      find.text(
        "This computer belongs to Mitchell. Dives will be added to "
        "Mitchell's log.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('names another chosen profile and selects it', (tester) async {
    await pump(
      tester,
      const ImportTargetChoice(ownerDiverId: 'mitchell', chosenDiverId: 'bill'),
    );

    expect(
      find.text(
        "This computer belongs to Mitchell. Dives will be added to Bill's log.",
      ),
      findsOneWidget,
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.value, 'bill');
  });

  testWidgets('picking a profile reports it', (tester) async {
    final changes = await pump(
      tester,
      const ImportTargetChoice(
        ownerDiverId: 'mitchell',
        chosenDiverId: 'mitchell',
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bill').last);
    await tester.pumpAndSettle();

    expect(changes, ['bill']);
  });

  testWidgets('renders nothing when the owner is no longer a profile', (
    tester,
  ) async {
    await pump(
      tester,
      const ImportTargetChoice(
        ownerDiverId: 'mitchell',
        chosenDiverId: 'mitchell',
      ),
      divers: [_diver('bill', 'Bill')],
    );

    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.textContaining('belongs to'), findsNothing);
  });
  testWidgets('holds the picker while the download is re-checked', (
    tester,
  ) async {
    await pump(
      tester,
      const ImportTargetChoice(ownerDiverId: 'mitchell', chosenDiverId: 'bill'),
      busy: true,
    );

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(dropdown.onChanged, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('a chosen profile that is gone falls back to the owner', (
    tester,
  ) async {
    final changes = await pump(
      tester,
      const ImportTargetChoice(ownerDiverId: 'mitchell', chosenDiverId: 'ana'),
    );
    await tester.pump();

    expect(changes, ['mitchell']);
  });
}
