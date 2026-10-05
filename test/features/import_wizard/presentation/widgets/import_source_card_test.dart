import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_source_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();
const _units = UnitFormatter(AppSettings());

ImportSourceLines _lines(ImportSourceInfo source) =>
    importSourceLines(source, l10n: _l10n, units: _units);

Widget _host(ImportSourceInfo source, {double width = 390}) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ImportSourceCard(source: source),
        ),
      ),
    ),
  ),
);

void main() {
  // Month names come from Intl.defaultLocale, a process global another test
  // file in the same isolate may have changed; MaterialApp.locale does not
  // pin it. Setting the global makes intl demand real symbol data, so load
  // it first.
  late String? previousLocale;
  setUpAll(() => initializeDateFormatting('en'));
  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });
  tearDown(() => Intl.defaultLocale = previousLocale);

  group('importSourceLines', () {
    test('a readable empty file shows its zero size', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'File Import',
          details: ImportSourceDetails(
            title: 'empty.uddf',
            formats: ['UDDF'],
            sizeBytes: 0,
          ),
        ),
      );
      expect(lines.details, ['UDDF', '0 B']);
    });

    test('dive computer: name, model, then serial, firmware, connection', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.diveComputer,
          displayName: 'Dive Computer',
          details: ImportSourceDetails(
            title: 'My Perdix',
            model: 'Shearwater Perdix 2',
            serialNumber: '1A2B3C',
            firmwareVersion: '92',
            connection: DeviceConnectionType.ble,
          ),
        ),
      );
      expect(lines.title, 'My Perdix');
      expect(lines.details, [
        'Shearwater Perdix 2',
        'S/N 1A2B3C · Firmware 92 · Bluetooth LE',
      ]);
    });

    test('drops the model line when it repeats the name', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.diveComputer,
          displayName: 'Dive Computer',
          details: ImportSourceDetails(
            title: 'Shearwater Perdix 2',
            model: 'Shearwater Perdix 2',
            connection: DeviceConnectionType.usb,
          ),
        ),
      );
      expect(lines.title, 'Shearwater Perdix 2');
      expect(lines.details, ['USB']);
    });

    test('names every connection type', () {
      String connection(DeviceConnectionType type) => _lines(
        ImportSourceInfo(
          type: ImportSourceType.diveComputer,
          displayName: 'Dive Computer',
          details: ImportSourceDetails(connection: type),
        ),
      ).details.single;

      expect(connection(DeviceConnectionType.ble), 'Bluetooth LE');
      expect(connection(DeviceConnectionType.bluetoothClassic), 'Bluetooth');
      expect(connection(DeviceConnectionType.usb), 'USB');
      expect(connection(DeviceConnectionType.infrared), 'Infrared');
    });

    test('falls back to the display name with no details', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.garminCloud,
          displayName: 'Garmin Connect',
        ),
      );
      expect(lines.title, 'Garmin Connect');
      expect(lines.details, isEmpty);
    });

    test('single file: format, source app, then size', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'File Import',
          details: ImportSourceDetails(
            title: 'logbook.uddf',
            formats: ['UDDF'],
            sourceApp: 'Subsurface',
            sizeBytes: 412 * 1024,
          ),
        ),
      );
      expect(lines.title, 'logbook.uddf');
      expect(lines.details, ['UDDF · from Subsurface', '412 KB']);
    });

    test('omits the source app when the format already names it', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'File Import',
          details: ImportSourceDetails(
            title: 'logbook.xml',
            formats: ['Subsurface XML'],
            sourceApp: 'Subsurface',
          ),
        ),
      );
      expect(lines.details, ['Subsurface XML']);
    });

    test('batch: file count as the name, formats listed', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.universal,
          displayName: 'File Import',
          details: ImportSourceDetails(
            fileCount: 12,
            formats: ['UDDF', 'Garmin FIT'],
            sizeBytes: 3 * 1024 * 1024,
          ),
        ),
      );
      expect(lines.title, '12 files');
      expect(lines.details, ['UDDF, Garmin FIT', '3.0 MB']);
    });

    test('HealthKit: the chosen date range in the diver date format', () {
      final lines = _lines(
        ImportSourceInfo(
          type: ImportSourceType.healthKit,
          displayName: 'HealthKit Import',
          details: ImportSourceDetails(
            title: 'Apple Health',
            rangeStart: DateTime(2026, 9, 5),
            rangeEnd: DateTime(2026, 10, 5),
          ),
        ),
      );
      expect(lines.title, 'Apple Health');
      expect(lines.details, ['Sep 5 - Oct 5, 2026']);
    });

    test('cloud: account, then the devices found', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.garminCloud,
          displayName: 'Garmin Connect',
          details: ImportSourceDetails(
            account: 'diver@example.com',
            deviceModels: ['Descent Mk3i', 'Descent G1'],
          ),
        ),
      );
      expect(lines.title, 'Garmin Connect');
      expect(lines.details, ['diver@example.com', 'Descent Mk3i, Descent G1']);
    });

    test('blank fields are treated as absent', () {
      final lines = _lines(
        const ImportSourceInfo(
          type: ImportSourceType.diveComputer,
          displayName: 'Dive Computer',
          details: ImportSourceDetails(
            title: '  ',
            model: '',
            serialNumber: ' ',
            firmwareVersion: '',
          ),
        ),
      );
      expect(lines.title, 'Dive Computer');
      expect(lines.details, isEmpty);
    });
  });

  group('ImportSourceCard', () {
    testWidgets('shows the name and each detail line', (tester) async {
      await tester.pumpWidget(
        _host(
          const ImportSourceInfo(
            type: ImportSourceType.diveComputer,
            displayName: 'Dive Computer',
            details: ImportSourceDetails(
              title: 'My Perdix',
              model: 'Shearwater Perdix 2',
              serialNumber: '1A2B3C',
              connection: DeviceConnectionType.ble,
            ),
          ),
        ),
      );
      expect(find.text('My Perdix'), findsOneWidget);
      expect(find.text('Shearwater Perdix 2'), findsOneWidget);
      expect(find.text('S/N 1A2B3C · Bluetooth LE'), findsOneWidget);
      expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    });

    testWidgets('a long file name ellipsizes instead of overflowing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ImportSourceInfo(
            type: ImportSourceType.universal,
            displayName: 'File Import',
            details: ImportSourceDetails(
              title: '${'very-long-file-name-' * 10}.uddf',
              formats: const ['UDDF'],
            ),
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.textContaining('very-long'));
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('picks an icon per source type', (tester) async {
      const cases = {
        ImportSourceType.universal: Icons.insert_drive_file_outlined,
        ImportSourceType.healthKit: Icons.favorite_outline,
        ImportSourceType.suuntoCloud: Icons.cloud_download_outlined,
        ImportSourceType.diveComputer: Icons.watch_outlined,
      };
      await tester.pumpWidget(
        _host(
          const ImportSourceInfo(
            type: ImportSourceType.diveComputer,
            displayName: 'x',
            details: ImportSourceDetails(connection: DeviceConnectionType.usb),
          ),
        ),
      );
      expect(find.byIcon(Icons.usb), findsOneWidget);
      for (final MapEntry(key: type, value: icon) in cases.entries) {
        await tester.pumpWidget(
          _host(ImportSourceInfo(type: type, displayName: 'x')),
        );
        expect(find.byIcon(icon), findsOneWidget, reason: '$type');
      }
      await tester.pumpWidget(
        _host(
          const ImportSourceInfo(
            type: ImportSourceType.universal,
            displayName: 'x',
            details: ImportSourceDetails(fileCount: 3),
          ),
        ),
      );
      expect(find.byIcon(Icons.folder_copy_outlined), findsOneWidget);
    });
  });
}
