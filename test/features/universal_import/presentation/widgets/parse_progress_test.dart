// With parsing off the UI isolate the wizard is live during a large file, so
// it has to say so. A single file used to show nothing at all: the freeze hid
// that there was no progress on Confirm Source.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/features/universal_import/presentation/widgets/file_triage_step.dart';
import 'package:submersion/features/universal_import/presentation/widgets/source_confirmation_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingNotifier extends UniversalImportNotifier {
  _RecordingNotifier(super.ref);

  int cancels = 0;

  @override
  void cancelParse() => cancels++;
}

const _detection = DetectionResult(
  format: ImportFormat.subsurfaceXml,
  sourceApp: SourceApp.subsurface,
  confidence: 0.95,
);

Future<_RecordingNotifier> _pump(
  WidgetTester tester,
  Widget step, {
  required UniversalImportState Function(UniversalImportState) seed,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await tester.runAsync(SharedPreferences.getInstance);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs!),
      universalImportNotifierProvider.overrideWith(_RecordingNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  final notifier =
      container.read(universalImportNotifierProvider.notifier)
          as _RecordingNotifier;
  notifier.state = seed(notifier.state);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        // flutter_test forwards the host machine's locale list rather than a
        // fixed en_US, and the app ships 11 locales.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: step),
      ),
    ),
  );
  await tester.pump();
  return notifier;
}

void main() {
  group('Confirm Source', () {
    testWidgets('shows a running bar and Cancel while a file parses', (
      tester,
    ) async {
      final notifier = await _pump(
        tester,
        const SourceConfirmationStep(),
        seed: (s) => s.copyWith(detectionResult: _detection, isLoading: true),
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);
      expect(find.text('Parsing file 1 of 1…'), findsOneWidget);

      await tester.tap(find.text('Cancel'));

      expect(notifier.cancels, 1);
    });

    testWidgets('shows neither once nothing is parsing', (tester) async {
      await _pump(
        tester,
        const SourceConfirmationStep(),
        seed: (s) => s.copyWith(detectionResult: _detection),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('batch triage', () {
    testWidgets('counts the files and cancels through the same path', (
      tester,
    ) async {
      final notifier = await _pump(
        tester,
        const FileTriageStep(),
        seed: (s) => s.copyWith(
          detectionResult: _detection,
          isLoading: true,
          parseCurrent: 2,
          parseTotal: 4,
        ),
      );

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
      expect(find.text('Parsing file 2 of 4…'), findsOneWidget);

      await tester.tap(find.text('Cancel'));

      expect(notifier.cancels, 1);
    });
  });
}
