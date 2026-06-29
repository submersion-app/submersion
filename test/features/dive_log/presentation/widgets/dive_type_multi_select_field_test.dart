import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  DiveTypeEntity type(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Widget harness({
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
    bool allowEmpty = false,
  }) {
    return ProviderScope(
      overrides: [
        diveTypesProvider.overrideWith(
          (ref) async => [
            type('shore', 'Shore'),
            type('wreck', 'Wreck'),
            type('night', 'Night'),
          ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DiveTypeMultiSelectField(
            selectedTypeIds: selected,
            onChanged: onChanged,
            allowEmpty: allowEmpty,
          ),
        ),
      ),
    );
  }

  testWidgets('renders a chip per selected type', (tester) async {
    await tester.pumpWidget(harness(selected: ['shore'], onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Shore'), findsOneWidget);
  });

  testWidgets(
    'tapping the field opens a checklist and toggling fires onChanged',
    (tester) async {
      List<String>? result;
      await tester.pumpWidget(
        harness(selected: ['shore'], onChanged: (v) => result = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first); // open the checklist
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNWidgets(3));

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Wreck'));
      await tester.pumpAndSettle();

      expect(result, ['shore', 'wreck']);
    },
  );

  testWidgets('checklist stays open across multiple sequential toggles', (
    tester,
  ) async {
    final results = <List<String>>[];
    await tester.pumpWidget(
      harness(selected: ['shore'], onChanged: results.add),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Wreck'));
    await tester.pumpAndSettle();

    // The sheet stays open so a second type is reachable without reopening.
    expect(find.widgetWithText(CheckboxListTile, 'Night'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Night'));
    await tester.pumpAndSettle();

    expect(results, [
      ['shore', 'wreck'],
      ['shore', 'wreck', 'night'],
    ]);
  });

  testWidgets('cannot uncheck the last remaining type (>= 1)', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(selected: ['shore'], onChanged: (v) => result = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Shore'),
    ); // try to uncheck the only type
    await tester.pumpAndSettle();

    expect(result, isNull); // the uncheck was ignored
  });

  testWidgets('allowEmpty lets the last type be unchecked (bulk mode)', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(
        selected: ['shore'],
        onChanged: (v) => result = v,
        allowEmpty: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Shore'));
    await tester.pumpAndSettle();

    expect(result, isEmpty); // bulk mode allows clearing
  });

  // Regression: #429 -- diveTypesProvider self-invalidates on every dive_types
  // table write (e.g. an incoming sync). On reload it drops back into a loading
  // state while Riverpod keeps the previous value (hasValue stays true). The
  // field must keep showing its chips across that background reload instead of
  // flashing a bare LinearProgressIndicator.
  //
  // The reload is driven through a watched dependency: that is the state where
  // AsyncValue.when() surfaces the loading branch despite retaining a value
  // (skipLoadingOnReload defaults to false), which is the exact flicker users
  // see when a sync ticks the table.
  testWidgets('keeps the selected chips visible while the provider reloads', (
    tester,
  ) async {
    final reloadKey = StateProvider<int>((ref) => 0);
    final loads = <Completer<List<DiveTypeEntity>>>[];
    Future<List<DiveTypeEntity>> nextLoad() {
      final completer = Completer<List<DiveTypeEntity>>();
      loads.add(completer);
      return completer.future;
    }

    final types = [type('shore', 'Shore'), type('wreck', 'Wreck')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveTypesProvider.overrideWith((ref) {
            ref.watch(reloadKey);
            return nextLoad();
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveTypeMultiSelectField(
              selectedTypeIds: const ['shore'],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    // First load resolves -> the populated field is on screen.
    loads.last.complete(types);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Shore'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // A dive_types write lands: the provider rebuilds and is briefly pending
    // again while retaining its previous value.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveTypeMultiSelectField)),
      listen: false,
    );
    container.read(reloadKey.notifier).state++;
    await tester.pump();

    expect(
      find.byType(LinearProgressIndicator),
      findsNothing,
      reason: 'a background reload must not replace the field with a spinner',
    );
    expect(find.widgetWithText(Chip, 'Shore'), findsOneWidget);

    // Let the reload settle so the test ends cleanly.
    loads.last.complete(types);
    await tester.pumpAndSettle();
  });

  testWidgets('shows a progress indicator on the very first load', (
    tester,
  ) async {
    final completer = Completer<List<DiveTypeEntity>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [diveTypesProvider.overrideWith((ref) => completer.future)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveTypeMultiSelectField(
              selectedTypeIds: const ['shore'],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // No value has ever arrived, so the spinner is the correct placeholder.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(Chip), findsNothing);

    completer.complete([type('shore', 'Shore')]);
    await tester.pumpAndSettle();
  });
}
