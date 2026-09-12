import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/domain/entities/diver_data_summary.dart';
import 'package:submersion/features/data_quality/presentation/widgets/delete_duplicate_dialog.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Opens the dialog and hands its result future to [onOpened]. The future
/// only completes when the dialog closes, so it cannot be awaited here.
Future<void> _open(
  WidgetTester tester, {
  DiveIdentityLabel? keep,
  DiveIdentityLabel? delete,
  DiverDataSummary? carries,
  void Function(Future<bool?> result)? onOpened,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () {
            // Opened first, handed over second: a null-aware call would
            // skip evaluating its argument, and the dialog with it.
            final result = showDeleteDuplicateDialog(
              context,
              keep: keep,
              delete: delete,
              carries: carries,
            );
            onOpened?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  // Let the localizations resolve before tapping; a tap on the first frame
  // lands before the button is hit-testable and only prints a warning.
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names both dives with their stats line', (tester) async {
    await _open(
      tester,
      keep: const DiveIdentityLabel(
        headline: 'Dive #12',
        stats: '20 m · 35 min',
      ),
      delete: const DiveIdentityLabel(
        headline: 'Dive #13',
        stats: '1.7 m · 0 min',
      ),
    );
    expect(find.text('Keep: Dive #12 · 20 m · 35 min'), findsOneWidget);
    expect(find.text('Delete: Dive #13 · 1.7 m · 0 min'), findsOneWidget);
  });

  testWidgets('a headline without stats stands alone', (tester) async {
    await _open(
      tester,
      keep: const DiveIdentityLabel(headline: 'Dive #12'),
      delete: const DiveIdentityLabel(headline: 'Dive #13'),
    );
    expect(find.text('Keep: Dive #12'), findsOneWidget);
    expect(find.text('Delete: Dive #13'), findsOneWidget);
  });

  testWidgets('an unresolved dive is named as unknown, never as an id', (
    tester,
  ) async {
    await _open(tester, keep: null, delete: null);
    expect(find.textContaining('Keep: '), findsOneWidget);
    expect(find.text('Keep: '), findsNothing);
    expect(find.textContaining('Delete: '), findsOneWidget);
    expect(find.text('Delete: '), findsNothing);
  });

  testWidgets('says what the copy it deletes carries', (tester) async {
    await _open(
      tester,
      keep: const DiveIdentityLabel(headline: 'Dive #12'),
      delete: const DiveIdentityLabel(headline: 'Dive #13'),
      carries: const DiverDataSummary(gear: 6, buddies: 2, hasNotes: true),
    );
    expect(
      find.text(
        'This copy also has: 6 gear items \u00b7 2 buddies \u00b7 notes',
      ),
      findsOneWidget,
    );
  });

  // A copy holding nothing of the diver's own is the case the detector is
  // supposed to leave to the repair, so the dialog stays as it was: an extra
  // line saying "nothing" would only make the safe case look risky.
  testWidgets('adds nothing when the copy holds nothing', (tester) async {
    await _open(
      tester,
      keep: const DiveIdentityLabel(headline: 'Dive #12'),
      delete: const DiveIdentityLabel(headline: 'Dive #13'),
      carries: const DiverDataSummary(),
    );
    expect(find.textContaining('This copy also has'), findsNothing);
  });

  testWidgets('adds nothing when the copy could not be read', (tester) async {
    await _open(
      tester,
      keep: const DiveIdentityLabel(headline: 'Dive #12'),
      delete: const DiveIdentityLabel(headline: 'Dive #13'),
    );
    expect(find.textContaining('This copy also has'), findsNothing);
  });

  testWidgets('confirm resolves true, cancel resolves null', (tester) async {
    late Future<bool?> confirmed;
    await _open(
      tester,
      keep: const DiveIdentityLabel(headline: 'A'),
      delete: const DiveIdentityLabel(headline: 'B'),
      onOpened: (r) => confirmed = r,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);

    late Future<bool?> cancelled;
    await _open(
      tester,
      keep: const DiveIdentityLabel(headline: 'A'),
      delete: const DiveIdentityLabel(headline: 'B'),
      onOpened: (r) => cancelled = r,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await cancelled, isNull);
  });
}
