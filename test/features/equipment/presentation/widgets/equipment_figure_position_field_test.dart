import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The item form's "Position on figure" picker (issue #4493): offered in
/// the appearance block when the item can be drawn in more than one way,
/// listing only those spots.
void main() {
  EquipmentAttribute attr(String key, String value) =>
      EquipmentAttribute.curated(equipmentId: '', key: key, valueText: value);

  Future<void> pump(
    WidgetTester tester, {
    required EquipmentType type,
    Map<String, EquipmentAttribute> values = const {},
    void Function(EquipmentAttribute)? onChanged,
    void Function(String)? onCleared,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentAttributeFormSection(
              type: type,
              group: AttributeGroup.appearance,
              values: values,
              units: const UnitFormatter(AppSettings()),
              onChanged: onChanged ?? (_) {},
              onCleared: onCleared ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field() => find.byWidgetPredicate(
    (w) =>
        w is DropdownButtonFormField<String?> &&
        '${w.key}'.contains(EquipmentAttrKeys.figurePosition),
  );

  testWidgets('a cylinder offers Automatic and its five spots', (tester) async {
    EquipmentAttribute? changed;
    await pump(tester, type: EquipmentType.tank, onChanged: (a) => changed = a);
    expect(find.text('Position on figure'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    await tester.tap(field());
    await tester.pumpAndSettle();
    for (final label in [
      'Back',
      'Stage, left',
      'Stage, right',
      'Sidemount, left',
      'Sidemount, right',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await tester.tap(find.text('Sidemount, right').last);
    await tester.pumpAndSettle();
    expect(changed?.key, EquipmentAttrKeys.figurePosition);
    expect(changed?.valueText, 'sidemount_right');
  });

  testWidgets('picking Automatic clears the spot', (tester) async {
    String? cleared;
    await pump(
      tester,
      type: EquipmentType.light,
      values: {
        EquipmentAttrKeys.figurePosition: attr(
          EquipmentAttrKeys.figurePosition,
          'chest_right',
        ),
      },
      onCleared: (key) => cleared = key,
    );
    expect(find.text('Chest, right'), findsOneWidget);
    await tester.tap(field());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Automatic').last);
    await tester.pumpAndSettle();
    expect(cleared, EquipmentAttrKeys.figurePosition);
  });

  testWidgets('an item drawn one way only gets no picker', (tester) async {
    await pump(tester, type: EquipmentType.mask);
    expect(find.text('Position on figure'), findsNothing);
    await pump(tester, type: EquipmentType.vest);
    expect(find.text('Position on figure'), findsNothing);
    // A console computer has one spot; a wrist one has two.
    await pump(
      tester,
      type: EquipmentType.computer,
      values: {'mount': attr('mount', 'console')},
    );
    expect(find.text('Position on figure'), findsNothing);
  });

  testWidgets('a spot the item no longer has artwork for reads as Automatic', (
    tester,
  ) async {
    // A stored spot an instrument has no artwork for (it came from another
    // type, or a sync peer) is ignored by the figure; the form must show
    // Automatic rather than throw on a value its dropdown does not offer.
    await pump(
      tester,
      type: EquipmentType.instrument,
      values: {
        EquipmentAttrKeys.figurePosition: attr(
          EquipmentAttrKeys.figurePosition,
          'mouth',
        ),
      },
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Automatic'), findsOneWidget);
  });

  testWidgets('a cylinder offers Worn as in its spec fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentAttributeFormSection(
              type: EquipmentType.tank,
              values: const {},
              units: const UnitFormatter(AppSettings()),
              onChanged: (_) {},
              onCleared: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Worn as'), findsOneWidget);
    expect(find.text('Position on figure'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('attr-field-worn_as')),
    );
    await tester.tap(find.byKey(const ValueKey('attr-field-worn_as')));
    await tester.pumpAndSettle();
    for (final label in [
      'Back mount',
      'Sidemount, left',
      'Sidemount, right',
      'Stage',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });
}
