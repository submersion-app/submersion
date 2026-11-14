import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/scan_step_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'scan_step_test_support.dart';

/// The USB tab's manufacturer headings fold like the Equipment list's groups
/// (issue #4480). With more than 350 models, the tab opens with every brand
/// folded, so the list reads as an index of brands. A search or a brand
/// picked in the dropdown shows every matching group open, and folds made
/// while one is on are dropped when it changes.
DeviceModel _model(String brand, String name) => DeviceModel(
  id: '${brand}_$name',
  manufacturer: brand,
  model: name,
  connectionTypes: const [DeviceConnectionType.usb],
);

final _devices = <String, List<DeviceModel>>{
  'Mares': [_model('Mares', 'Genius'), _model('Mares', 'Puck Pro')],
  'Shearwater': [_model('Shearwater', 'Perdix'), _model('Shearwater', 'Teric')],
  'Suunto': [_model('Suunto', 'D5')],
};

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ScanStepWidget)));

Future<void> _pumpUsbTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(buildScanStepTestWidget(usbDevices: _devices));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_l10n(tester).diveComputer_scan_tabUsb));
  await tester.pumpAndSettle();
}

/// Scoped to the device list: the dropdown keeps an offstage clone of every
/// brand entry.
Finder _inList(String text) =>
    find.descendant(of: find.byType(SliverList), matching: find.text(text));

Finder _searchField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.prefixIcon != null,
);

Future<void> _toggle(WidgetTester tester, String brand) async {
  await tester.tap(_inList(brand));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens with every brand folded, each with its model count', (
    tester,
  ) async {
    await _pumpUsbTab(tester);

    expect(_inList('Mares'), findsOneWidget);
    expect(_inList('Shearwater'), findsOneWidget);
    expect(_inList('Suunto'), findsOneWidget);
    expect(_inList('Genius'), findsNothing);
    expect(_inList('Perdix'), findsNothing);
    expect(_inList('D5'), findsNothing);

    final l10n = _l10n(tester);
    expect(
      _inList(l10n.diveComputer_discovery_usbModelCount(2)),
      findsNWidgets(2),
    );
    expect(
      _inList(l10n.diveComputer_discovery_usbModelCount(1)),
      findsOneWidget,
    );
  });

  testWidgets('tapping a brand opens it, and tapping again folds it', (
    tester,
  ) async {
    await _pumpUsbTab(tester);

    await _toggle(tester, 'Shearwater');
    expect(_inList('Perdix'), findsOneWidget);
    expect(_inList('Teric'), findsOneWidget);
    expect(_inList('Genius'), findsNothing, reason: 'other brands stay folded');

    await _toggle(tester, 'Shearwater');
    expect(_inList('Perdix'), findsNothing);
  });

  testWidgets('marks the heading expanded for assistive tech', (tester) async {
    await _pumpUsbTab(tester);
    final handle = tester.ensureSemantics();

    expect(
      tester.getSemantics(_inList('Suunto')),
      isSemantics(isButton: true, isHeader: true, hasExpandedState: true),
    );
    expect(
      tester.getSemantics(_inList('Suunto')),
      isNot(isSemantics(isExpanded: true)),
    );

    await _toggle(tester, 'Suunto');
    expect(
      tester.getSemantics(_inList('Suunto')),
      isSemantics(isExpanded: true),
    );
    handle.dispose();
  });

  testWidgets('a search shows every matching brand open', (tester) async {
    await _pumpUsbTab(tester);

    await tester.enterText(_searchField(), 'e');
    await tester.pumpAndSettle();

    expect(_inList('Genius'), findsOneWidget);
    expect(_inList('Perdix'), findsOneWidget);
  });

  testWidgets('folds made during a search are dropped when it clears', (
    tester,
  ) async {
    await _pumpUsbTab(tester);
    await _toggle(tester, 'Suunto');

    await tester.enterText(_searchField(), 'e');
    await tester.pumpAndSettle();
    await _toggle(tester, 'Mares');
    expect(_inList('Genius'), findsNothing);

    await tester.enterText(_searchField(), '');
    await tester.pumpAndSettle();

    // Back to the folds from before the search: Suunto open, the rest folded.
    expect(_inList('D5'), findsOneWidget);
    expect(_inList('Genius'), findsNothing);
    expect(_inList('Perdix'), findsNothing);

    // A new search shows Mares open again.
    await tester.enterText(_searchField(), 'Genius');
    await tester.pumpAndSettle();
    expect(_inList('Genius'), findsOneWidget);
  });

  testWidgets('a brand picked in the dropdown shows open', (tester) async {
    await _pumpUsbTab(tester);

    await tester.tap(find.byType(DropdownMenu<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Mares').last);
    await tester.pumpAndSettle();

    expect(_inList('Genius'), findsOneWidget);
    expect(_inList('Puck Pro'), findsOneWidget);
    expect(_inList('Shearwater'), findsNothing);
  });

  testWidgets('tapping a model in an open brand selects it', (tester) async {
    DeviceModel? captured;
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildScanStepTestWidget(
        usbDevices: _devices,
        onDeviceSelected: (device) => captured = device.recognizedModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n(tester).diveComputer_scan_tabUsb));
    await tester.pumpAndSettle();

    await _toggle(tester, 'Shearwater');
    await tester.tap(_inList('Teric'));
    await tester.pumpAndSettle();

    expect(captured?.id, 'Shearwater_Teric');
  });
}
