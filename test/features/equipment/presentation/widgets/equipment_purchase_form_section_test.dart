import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required EquipmentType type,
    required AttributeGroup group,
    Map<String, EquipmentAttribute> values = const {},
    void Function(EquipmentAttribute)? onChanged,
    void Function(String)? onCleared,
    GlobalKey<FormState>? formKey,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // Pinned: flutter_test forwards the HOST machine's locale list, so an
        // unpinned MaterialApp resolves to a translated UI on a non-English
        // dev machine and the validation-message assertion below fails.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: EquipmentAttributeFormSection(
                type: type,
                group: group,
                values: values,
                units: const UnitFormatter(AppSettings()),
                onChanged: onChanged ?? (_) {},
                onCleared: onCleared ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the purchase group renders only the purchase record', (
    tester,
  ) async {
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      group: AttributeGroup.purchase,
    );

    expect(find.byKey(const ValueKey('attr-field-sku')), findsOneWidget);
    expect(find.byKey(const ValueKey('attr-field-retailer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attr-field-product_url')),
      findsOneWidget,
    );
    // The wetsuit's physical specs belong to the other block.
    expect(find.byKey(const ValueKey('attr-field-thickness_mm')), findsNothing);
    expect(find.byKey(const ValueKey('attr-field-size')), findsNothing);
  });

  testWidgets('the spec group holds no purchase fields back', (tester) async {
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      group: AttributeGroup.spec,
    );

    expect(
      find.byKey(const ValueKey('attr-field-thickness_mm')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('attr-field-sku')), findsNothing);
    expect(find.byKey(const ValueKey('attr-field-retailer')), findsNothing);
    expect(find.byKey(const ValueKey('attr-field-product_url')), findsNothing);
  });

  testWidgets('the SKU field explains itself before anything is typed', (
    tester,
  ) async {
    // Issue #4236: the abbreviation alone left divers guessing, most likely
    // at the serial number. The explanation is helper text, not hint text,
    // because a hint only shows once the field is focused.
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
    );

    final sku = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('attr-field-sku')),
        matching: find.byType(TextField),
      ),
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(sku.decoration!.helperText, l10n.attrHelper_sku);
    expect(find.text(l10n.attrHelper_sku), findsOneWidget);
  });

  testWidgets('the retailer field carries no helper text', (tester) async {
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
    );

    final retailer = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('attr-field-retailer')),
        matching: find.byType(TextField),
      ),
    );
    expect(retailer.decoration!.helperText, isNull);
  });

  testWidgets('typing a SKU emits a curated attribute', (tester) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
      onChanged: (a) => emitted = a,
    );

    await tester.enterText(
      find.byKey(const ValueKey('attr-field-sku')),
      '  SP-MK25-EVO  ',
    );

    expect(emitted, isNotNull);
    expect(emitted!.key, EquipmentAttrKeys.sku);
    expect(emitted!.valueText, 'SP-MK25-EVO');
    expect(emitted!.isCustom, isFalse);
  });

  testWidgets('emptying the retailer clears the row rather than blanking it', (
    tester,
  ) async {
    // "Unset" is "no row" in the attribute store, so an emptied field must
    // report a clear, not an empty string.
    final cleared = <String>[];
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
      values: {
        EquipmentAttrKeys.retailer: EquipmentAttribute.curated(
          equipmentId: 'e1',
          key: EquipmentAttrKeys.retailer,
        ).copyWith(valueText: 'Dive Shop Ltd'),
      },
      onCleared: cleared.add,
    );

    await tester.enterText(
      find.byKey(const ValueKey('attr-field-retailer')),
      '   ',
    );

    expect(cleared, [EquipmentAttrKeys.retailer]);
  });

  testWidgets('a web link that is not a link fails validation', (tester) async {
    final formKey = GlobalKey<FormState>();
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
      formKey: formKey,
    );

    await tester.enterText(
      find.byKey(const ValueKey('attr-field-product_url')),
      'receipt in the drawer',
    );
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Enter a web address, e.g. shop.example.com'),
      findsOneWidget,
    );
  });

  testWidgets('the pinned locale survives a non-English host', (tester) async {
    // Proves the `locale:` pin above is load-bearing rather than decorative:
    // flutter_test forwards the host machine's locale list, and this app
    // supports French, so without the pin the form would render in French and
    // the assertion below would find nothing.
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final formKey = GlobalKey<FormState>();
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
      formKey: formKey,
    );

    await tester.enterText(
      find.byKey(const ValueKey('attr-field-product_url')),
      'receipt in the drawer',
    );
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(
      find.text('Enter a web address, e.g. shop.example.com'),
      findsOneWidget,
    );
  });

  testWidgets('a bare host validates, and so does an empty field', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      group: AttributeGroup.purchase,
      formKey: formKey,
    );

    expect(formKey.currentState!.validate(), isTrue);

    await tester.enterText(
      find.byKey(const ValueKey('attr-field-product_url')),
      'shop.example.com/mk25',
    );
    expect(formKey.currentState!.validate(), isTrue);
  });
}
