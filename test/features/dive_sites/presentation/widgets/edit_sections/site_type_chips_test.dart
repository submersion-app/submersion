import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/site_type_chips.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';

/// The site type chips the site page's header block edits with (issue
/// #1765), with the cases the deleted form's section pinned (issue #4527,
/// phase 2, plan 7).
void main() {
  final l = AppLocalizationsEn();
  final now = DateTime(2026);
  final types = [
    SiteTypeEntity(
      id: 'wreck',
      name: 'Wreck',
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    SiteTypeEntity(
      id: 'lake',
      name: 'Lake',
      isBuiltIn: true,
      createdAt: now,
      updatedAt: now,
    ),
    SiteTypeEntity(
      id: 'mine',
      diverId: 'diver-1',
      name: 'Mine',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  /// Pumps the chips with [selected], keeping each reported selection as
  /// the next one, and returns what was reported.
  Future<List<Set<String>>> pump(
    WidgetTester tester, {
    Set<String> selected = const {},
    Set<String> hidden = const {},
    Set<String> keep = const {},
    VoidCallback? onManageTypes,
  }) async {
    final reported = <Set<String>>[];
    var current = selected;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SiteTypeChips(
              allTypes: types,
              selectedTypeIds: current,
              hiddenTypeIds: hidden,
              keepTypeIds: keep,
              onManageTypes: onManageTypes,
              onTypesChanged: (ids) {
                reported.add(ids);
                setState(() => current = ids);
              },
            ),
          ),
        ),
      ),
    );
    return reported;
  }

  FilterChip chip(WidgetTester tester, String name) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, name));

  testWidgets('ticking and unticking a chip reports the new selection', (
    tester,
  ) async {
    final reported = await pump(tester, selected: {'wreck'});

    await tester.tap(find.text('Lake'));
    await tester.pump();
    expect(reported.last, {'wreck', 'lake'});

    await tester.tap(find.text('Wreck'));
    await tester.pump();
    expect(reported.last, {'lake'});
    expect(chip(tester, 'Wreck').selected, isFalse);
  });

  testWidgets('the manage link shows only with a handler, and runs it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(l.diveSites_edit_typeTags_manageTypes), findsNothing);

    var managed = 0;
    await pump(tester, onManageTypes: () => managed++);
    await tester.tap(find.text(l.diveSites_edit_typeTags_manageTypes));
    expect(managed, 1);
  });

  testWidgets('the manage link rides the types overline, not the chips', (
    tester,
  ) async {
    await pump(tester, onManageTypes: () {});

    final overline = find.byType(FormOverline);
    expect(overline, findsOneWidget);
    expect(
      find.descendant(
        of: overline,
        matching: find.text(l.diveSites_edit_typeTags_typesLabel.toUpperCase()),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: overline,
        matching: find.text(l.diveSites_edit_typeTags_manageTypes),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Wrap),
        matching: find.text(l.diveSites_edit_typeTags_manageTypes),
      ),
      findsNothing,
    );
  });

  testWidgets('hidden built-in types leave the chips', (tester) async {
    await pump(tester, hidden: {'lake'});

    expect(find.text('Lake'), findsNothing);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
  });

  testWidgets('a hidden type the site had stays after it is unticked', (
    tester,
  ) async {
    final reported = await pump(
      tester,
      selected: {'lake'},
      hidden: {'lake'},
      keep: {'lake'},
    );

    await tester.tap(find.text('Lake'));
    await tester.pump();

    expect(reported.last, isEmpty);
    expect(find.text('Lake'), findsOneWidget);
    expect(chip(tester, 'Lake').selected, isFalse);
  });
}
