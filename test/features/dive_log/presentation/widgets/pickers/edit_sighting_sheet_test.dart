import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_profile_picker.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _sighting = Sighting(
  id: 's1',
  diveId: 'dive-1',
  speciesId: 'sp1',
  speciesName: 'Eagle Ray',
  speciesCategory: SpeciesCategory.ray,
  abundance: SightingAbundance.exact,
  count: 2,
  notes: 'pair near the wall',
);

Future<void> _pump(
  WidgetTester tester, {
  required void Function(Sighting) onSave,
  required VoidCallback onDelete,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: EditSightingSheet(
            sighting: _sighting,
            onSave: onSave,
            onDelete: onDelete,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders species name, count and notes', (tester) async {
    await _pump(tester, onSave: (_) {}, onDelete: () {});
    expect(find.text('Eagle Ray'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Exact'))
          .selected,
      isTrue,
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('pair near the wall'), findsOneWidget);
  });

  testWidgets('saving untouched keeps the exact count', (tester) async {
    Sighting? saved;
    await _pump(tester, onSave: (s) => saved = s, onDelete: () {});

    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(saved?.amount, (abundance: SightingAbundance.exact, count: 2));
  });

  testWidgets('a REEF group saves with count 1', (tester) async {
    Sighting? saved;
    await _pump(tester, onSave: (s) => saved = s, onDelete: () {});

    await tester.tap(find.text('Many'));
    await tester.pump();
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(saved?.amount, (abundance: SightingAbundance.many, count: 1));
  });

  testWidgets('count buttons adjust and save returns updated sighting', (
    tester,
  ) async {
    Sighting? saved;
    await _pump(tester, onSave: (s) => saved = s, onDelete: () {});

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'single ray');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(saved?.amount, (abundance: SightingAbundance.exact, count: 1));
    expect(saved?.notes, 'single ray');
  });

  testWidgets('fits a small phone with the keyboard up', (tester) async {
    // The "How many" chips and stepper made the sheet taller; it scrolls
    // rather than overflowing (an overflow fails the test).
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: EditSightingSheet(
              sighting: _sighting,
              onSave: (_) {},
              onDelete: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Save Changes'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation before firing onDelete', (
    tester,
  ) async {
    var deleted = 0;
    await _pump(tester, onSave: (_) {}, onDelete: () => deleted++);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('Eagle Ray'), findsWidgets);

    // Cancel keeps the sighting.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(deleted, 0);

    // Confirm removes it.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  group('Seen at (issue #5092)', () {
    final profile = [
      for (var t = 0; t <= 3000; t += 10)
        DiveProfilePoint(timestamp: t, depth: t <= 600 ? t / 20 : 30),
    ];
    const units = UnitFormatter(AppSettings());

    Future<void> pumpTimed(
      WidgetTester tester, {
      Sighting sighting = _sighting,
      required void Function(Sighting) onSave,
      List<DiveProfilePoint>? onProfile,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditSightingSheet(
                sighting: sighting,
                onSave: onSave,
                onDelete: () {},
                time: SightingTimeContext(
                  profile: onProfile ?? profile,
                  maxSeconds: 3000,
                  units: units,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder seenAtField() => find.widgetWithText(TextFormField, 'Seen at');

    testWidgets('saves a typed time and shows its depth', (tester) async {
      Sighting? saved;
      await pumpTimed(tester, onSave: (s) => saved = s);
      await tester.enterText(seenAtField(), '12:30');
      await tester.pump();
      expect(find.text(units.formatDepth(30)), findsOneWidget);

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saved?.seenAtSeconds, 750);
    });

    testWidgets('picking on the profile fills the time', (tester) async {
      Sighting? saved;
      await pumpTimed(tester, onSave: (s) => saved = s);
      await tester.tap(find.byType(MiniProfilePicker));
      await tester.pump();

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saved?.seenAtSeconds, inInclusiveRange(1200, 1800));
    });

    testWidgets('clearing saves no time', (tester) async {
      Sighting? saved;
      await pumpTimed(
        tester,
        sighting: _sighting.copyWith(seenAtSeconds: 300),
        onSave: (s) => saved = s,
      );
      expect(find.text('5:00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sighting_seen_at_clear')));
      await tester.pump();

      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saved, isNotNull);
      expect(saved!.seenAtSeconds, isNull);
    });

    testWidgets('an empty time saves no time', (tester) async {
      Sighting? saved;
      await pumpTimed(tester, onSave: (s) => saved = s);
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saved, isNotNull);
      expect(saved!.seenAtSeconds, isNull);
    });

    testWidgets('a time past the dive shows the error and does not save', (
      tester,
    ) async {
      Sighting? saved;
      await pumpTimed(tester, onSave: (s) => saved = s);
      await tester.enterText(seenAtField(), '99:00');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saved, isNull);
      expect(find.text('Must be within the dive'), findsOneWidget);
    });

    testWidgets('a stored time past the dive does not block other edits', (
      tester,
    ) async {
      // A profile replaced after the time was typed can end before it.
      Sighting? saved;
      await pumpTimed(
        tester,
        sighting: _sighting.copyWith(seenAtSeconds: 4000),
        onSave: (s) => saved = s,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'pair near the wall'),
        'Cleaning station',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(saved?.notes, 'Cleaning station');
      expect(saved?.seenAtSeconds, 4000);
    });

    testWidgets('a dive with no profile has the time box and no picker', (
      tester,
    ) async {
      await pumpTimed(tester, onSave: (_) {}, onProfile: const []);
      expect(seenAtField(), findsOneWidget);
      expect(find.byType(MiniProfilePicker), findsNothing);
    });

    testWidgets('without a time context there is no Seen at field', (
      tester,
    ) async {
      await _pump(tester, onSave: (_) {}, onDelete: () {});
      expect(find.text('Seen at'), findsNothing);
    });
  });
}
