import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_file_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_file_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Uint8List _export({int activityType = 51}) => utf8.encode(
  jsonEncode({
    'DeviceLog': {
      'Header': {
        'DateTime': '2026-04-19T13:44:00.000+02:00',
        'ActivityType': activityType,
        'Device': {'Name': 'Ylivieska', 'SerialNumber': 'NS-1'},
        'DiveTime': 60,
      },
      'Samples': [
        {
          'TimeISO8601': '2026-04-19T13:44:00.000+02:00',
          'Depth': 1.0,
          'DiveEvents': {'DiveStatus': true},
          'DiveRoute': {'X': 0.0, 'Y': 0.0, 'Z': 1.0},
        },
        {
          'TimeISO8601': '2026-04-19T13:44:01.000+02:00',
          'Depth': 2.0,
          'DiveRoute': {'X': 0.5, 'Y': 0.8, 'Z': 2.0},
        },
      ],
    },
  }),
);

Widget _host({
  required List<SuuntoJsonFile> initialFiles,
  required void Function(List<SuuntoFileReadResult>) onRead,
  List<SuuntoFileReadResult> previousResults = const [],
  Future<List<SuuntoJsonFile>> Function()? picker,
}) => ProviderScope(
  overrides: [
    if (picker != null) suuntoJsonFilePickerProvider.overrideWithValue(picker),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SuuntoFileStep(
        initialFiles: initialFiles,
        previousResults: previousResults,
        onRead: onRead,
      ),
    ),
  ),
);

bool _ready(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SuuntoFileStep)),
).read(suuntoFileDivesReadyProvider);

void main() {
  testWidgets('reads handed-over files and lists why one was skipped', (
    tester,
  ) async {
    List<SuuntoFileReadResult>? read;
    await tester.pumpWidget(
      _host(
        initialFiles: [
          SuuntoJsonFile(name: 'nautic.json', bytes: _export()),
          SuuntoJsonFile(name: 'notes.txt', bytes: utf8.encode('not json')),
        ],
        onRead: (results) => read = results,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('nautic.json'), findsOneWidget);
    expect(find.text('Includes recorded route'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('Not a JSON file'), findsOneWidget);
    expect(find.text('1 dive ready to import'), findsOneWidget);
    expect(read!.where((r) => r.dive != null), hasLength(1));
    expect(_ready(tester), isTrue);
  });

  testWidgets('picks files and stays blocked when none is a dive', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      _host(
        initialFiles: const [],
        onRead: (_) {},
        picker: () async {
          picks++;
          return [
            SuuntoJsonFile(name: 'run.json', bytes: _export(activityType: 3)),
          ];
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(picks, 1);
    expect(find.text('Not a dive (another activity type)'), findsOneWidget);
    expect(_ready(tester), isFalse);
  });

  testWidgets('a picker that fails says so and lets the diver try again', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        initialFiles: const [],
        onRead: (_) {},
        picker: () async => throw const FileSystemException('denied'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();

    expect(find.text('Could not read file'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Choose files'),
        matching: find.bySubtype<OutlinedButton>(),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  // The wizard's PageView rebuilds a step it comes back to; the files read
  // or picked last time must reappear, not the hand-over again.
  testWidgets('coming back to the step shows what was read last time', (
    tester,
  ) async {
    var last = const <SuuntoFileReadResult>[];
    Widget step() => _host(
      initialFiles: [SuuntoJsonFile(name: 'handed.json', bytes: _export())],
      previousResults: last,
      onRead: (results) => last = results,
      picker: () async => [
        SuuntoJsonFile(name: 'picked.json', bytes: _export()),
      ],
    );

    await tester.pumpWidget(step());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose files'));
    await tester.pumpAndSettle();
    expect(find.text('picked.json'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(step());
    await tester.pumpAndSettle();

    expect(find.text('picked.json'), findsOneWidget);
    expect(find.text('handed.json'), findsNothing);
    expect(_ready(tester), isTrue);
  });
}
