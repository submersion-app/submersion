import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/features/firmware/presentation/widgets/firmware_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The item page's Firmware card (issue #5104).
void main() {
  late FirmwareCatalogue catalogue;
  late FirmwareModel perdix;
  late String? savedIntl;

  setUpAll(() {
    catalogue = FirmwareCatalogue.parse(
      File(
        p.join('test', 'fixtures', 'firmware_catalogue', 'sample.json'),
      ).readAsStringSync(),
    )!;
    perdix = catalogue.models.first;
  });
  setUp(() {
    savedIntl = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedIntl);

  EquipmentItem computer({String? firmware, String? page}) => EquipmentItem(
    id: 'perdix',
    name: 'Perdix 2',
    type: EquipmentType.computer,
    brand: 'Shearwater',
    model: 'Perdix 2',
    attributes: [
      if (firmware != null)
        EquipmentAttribute.curated(
          equipmentId: 'perdix',
          key: 'firmware_version',
          valueText: firmware,
        ),
      if (page != null)
        EquipmentAttribute.curated(
          equipmentId: 'perdix',
          key: 'firmware_page_url',
          valueText: page,
        ),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    EquipmentItem item,
    FirmwareStatus status, {
    double width = 800,
    List<DiveComputer> computers = const [],
    List<Object> extra = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          firmwareStatusesProvider.overrideWith(
            (ref) async => {item.id: status},
          ),
          computersForEquipmentProvider(
            item.id,
          ).overrideWith((ref) async => computers),
          ...extra,
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: FirmwareCard(item: item)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an update lists the newer releases with their links', (
    tester,
  ) async {
    await pump(
      tester,
      computer(firmware: 'V92'),
      FirmwareUpdateAvailable(perdix, perdix.releases.sublist(0, 2)),
    );

    expect(find.text('Firmware'), findsOneWidget);
    expect(find.text('V92'), findsOneWidget);
    expect(find.text('Update available: V95'), findsOneWidget);
    expect(find.text('Safety'), findsOneWidget);
    expect(find.text('V95'), findsOneWidget);
    expect(find.text('V94'), findsOneWidget);
    expect(
      find.text('Sample release used by tests in both repositories.'),
      findsOneWidget,
    );
    expect(find.text('Release notes'), findsNWidgets(2));
    expect(find.text('How to update'), findsOneWidget);
    expect(find.text('Firmware page'), findsOneWidget);
    expect(find.text('Log firmware update'), findsOneWidget);
  });

  testWidgets('up to date says so', (tester) async {
    await pump(tester, computer(firmware: 'V95'), FirmwareUpToDate(perdix));
    expect(find.text('Up to date'), findsOneWidget);
    expect(find.textContaining('Update available'), findsNothing);
  });

  testWidgets('a version the list lacks is never called an update', (
    tester,
  ) async {
    await pump(
      tester,
      computer(firmware: 'V90'),
      FirmwareUnknownVersion(perdix),
    );
    expect(find.text('Not in the firmware list. Latest: V95'), findsOneWidget);
    expect(find.textContaining('Update available'), findsNothing);
  });

  testWidgets('no version invites the diver to record one', (tester) async {
    await pump(tester, computer(), FirmwareNoVersion(perdix));
    expect(find.text('Not recorded'), findsOneWidget);
    expect(find.text('Latest: V95. Record yours to compare.'), findsOneWidget);
  });

  testWidgets('a version read from the download shows when the item has '
      'none', (tester) async {
    await pump(
      tester,
      computer(),
      FirmwareUpToDate(perdix),
      computers: [
        DiveComputer(
          id: 'dc',
          name: 'Perdix 2',
          firmwareVersion: '95',
          equipmentId: 'perdix',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    expect(find.text('95'), findsOneWidget);
  });

  testWidgets('gear not in the list shows its own page link', (tester) async {
    await pump(
      tester,
      computer(firmware: '1.0', page: 'example.com/fw'),
      const FirmwareNotListed(),
    );
    expect(find.text('1.0'), findsOneWidget);
    expect(find.text('Firmware page'), findsOneWidget);
    expect(find.textContaining('Latest'), findsNothing);
  });

  testWidgets('many newer releases show three and offer the rest', (
    tester,
  ) async {
    final many = List.generate(
      5,
      (i) => FirmwareRelease(version: 'V${100 - i}'),
    );
    final model = FirmwareModel(
      id: 'm',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      equipmentTypes: const {EquipmentType.computer},
      releases: [
        ...many,
        const FirmwareRelease(version: 'V90'),
      ],
    );
    await pump(
      tester,
      computer(firmware: 'V90'),
      FirmwareUpdateAvailable(model, many),
    );
    expect(find.text('V100'), findsOneWidget);
    expect(find.text('V98'), findsOneWidget);
    expect(find.text('V97'), findsNothing);
    await tester.tap(find.text('Show all releases (5)'));
    await tester.pumpAndSettle();
    expect(find.text('V96'), findsOneWidget);
  });

  testWidgets('long versions wrap on a phone', (tester) async {
    final long = 'Build ${'1234567890' * 5}';
    final model = FirmwareModel(
      id: 'm',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      equipmentTypes: const {EquipmentType.computer},
      releases: [
        FirmwareRelease(version: long, safety: true),
        const FirmwareRelease(version: 'V90'),
      ],
    );
    await pump(
      tester,
      computer(firmware: 'V90'),
      FirmwareUpdateAvailable(model, [model.releases.first]),
      width: 360,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets("the diver's own firmware page wins over the list's", (
    tester,
  ) async {
    String? opened;
    await pump(
      tester,
      computer(firmware: 'V95', page: 'https://my.example.org/fw'),
      FirmwareUpToDate(perdix),
      extra: [
        equipmentWebLinkLaunchProvider.overrideWithValue((uri) async {
          opened = uri.toString();
          return true;
        }),
      ],
    );
    await tester.tap(find.text('Firmware page'));
    await tester.pumpAndSettle();
    expect(opened, 'https://my.example.org/fw');
  });
  testWidgets('show all can be folded back', (tester) async {
    final many = List.generate(
      5,
      (i) => FirmwareRelease(version: 'V${100 - i}'),
    );
    final model = FirmwareModel(
      id: 'm',
      manufacturer: 'Shearwater',
      model: 'Perdix 2',
      equipmentTypes: const {EquipmentType.computer},
      releases: [
        ...many,
        const FirmwareRelease(version: 'V90'),
      ],
    );
    await pump(
      tester,
      computer(firmware: 'V90'),
      FirmwareUpdateAvailable(model, many),
    );
    await tester.tap(find.text('Show all releases (5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();
    expect(find.text('V96'), findsNothing);
  });

  testWidgets('log firmware update opens with the latest suggested', (
    tester,
  ) async {
    await pump(
      tester,
      computer(firmware: 'V92'),
      FirmwareUpdateAvailable(perdix, perdix.releases.sublist(0, 2)),
    );
    await tester.tap(find.byKey(const ValueKey('firmware-log-update')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('firmware-log-version')))
          .controller!
          .text,
      'V95',
    );
  });
}
