import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_ask_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_ask_row.dart';
import 'package:submersion/features/explore/domain/nl_engine.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../../helpers/test_app.dart';

class _Engine implements NlEngine {
  _Engine(this.answer);
  NlAvailability answer;
  final downloads = StreamController<double>();
  int downloadCalls = 0;

  @override
  Future<NlAvailability> availability(String localeTag) async => answer;

  @override
  Future<void> prepare() async {}

  @override
  Stream<double> download() {
    downloadCalls++;
    return downloads.stream;
  }

  @override
  Future<String> compile(String sentence, {required String localeTag}) =>
      Completer<String>().future;
}

void main() {
  late int asks;

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required _Engine engine,
    bool supported = true,
    Future<NlAvailability>? availability,
  }) async {
    asks = 0;
    // Not awaited: with no listener, close() completes only once its done
    // event is delivered, which would never happen.
    addTearDown(() => unawaited(engine.downloads.close()));
    late ProviderContainer container;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          nlEngineProvider.overrideWithValue(engine),
          explorePlatformSupportedProvider.overrideWithValue(supported),
          if (availability != null)
            exploreAvailabilityProvider.overrideWith((ref) => availability),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveAskRow(text: 'turtles in bonaire', onAsk: () => asks++);
          },
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('offers to ask the typed sentence', (tester) async {
    await pump(tester, engine: _Engine(NlAvailability.available));
    expect(find.text('Ask: turtles in bonaire'), findsOneWidget);
    await tester.tap(find.byKey(kDiveAskRowKey));
    expect(asks, 1);
  });

  testWidgets('is absent where the model cannot run', (tester) async {
    await pump(
      tester,
      engine: _Engine(NlAvailability.available),
      supported: false,
    );
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  testWidgets('is absent when the model is unavailable', (tester) async {
    await pump(tester, engine: _Engine(NlAvailability.deviceNotEligible));
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  // Review Focus 4.
  testWidgets('is absent while availability is still being asked', (
    tester,
  ) async {
    await pump(
      tester,
      engine: _Engine(NlAvailability.available),
      availability: Completer<NlAvailability>().future,
    );
    expect(find.byKey(kDiveAskRowKey), findsNothing);
  });

  testWidgets('offers the download, then re-probes', (tester) async {
    final engine = _Engine(NlAvailability.downloadable);
    await pump(tester, engine: engine);
    expect(find.text('Download the on-device model'), findsOneWidget);
    engine.answer = NlAvailability.downloading;
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    await tester.pump();
    expect(engine.downloadCalls, 1);
    expect(find.text('Downloading the model'), findsOneWidget);
    engine.answer = NlAvailability.available;
    await engine.downloads.close();
    await tester.pump();
    await tester.pump();
    expect(find.text('Ask: turtles in bonaire'), findsOneWidget);
  });

  // Copilot review: the download's progress was discarded.
  testWidgets('shows how far the download has got', (tester) async {
    final engine = _Engine(NlAvailability.downloadable);
    await pump(tester, engine: engine);
    engine.answer = NlAvailability.downloading;
    await tester.tap(find.byKey(kDiveAskRowKey));
    await tester.pump();
    await tester.pump();
    engine.downloads.add(0.4);
    await tester.pump();
    final spinner = tester.widget<CircularProgressIndicator>(
      find.descendant(
        of: find.byKey(kDiveAskRowKey),
        matching: find.byType(CircularProgressIndicator),
      ),
    );
    expect(spinner.value, 0.4);
    // Finish the download while the app is still up, as the platform would.
    engine.answer = NlAvailability.available;
    await engine.downloads.close();
    await tester.pump();
  });

  testWidgets('shows the running state and an error in words', (tester) async {
    final c = await pump(tester, engine: _Engine(NlAvailability.available));
    unawaited(c.read(diveAskProvider.notifier).ask('turtles'));
    await tester.pump();
    expect(find.text('Asking the on-device model'), findsOneWidget);
    c.read(diveAskProvider.notifier).reset();
    c.read(diveAskProvider.notifier).state = const AskState(
      error: NlError.quotaExceeded,
    );
    await tester.pump();
    expect(
      find.text('The on-device model is busy. Try again in a moment.'),
      findsOneWidget,
    );
  });

  test('every model error reads as a sentence', () {
    final l10n = AppLocalizationsEn();
    final texts = {for (final e in NlError.values) e: nlErrorText(l10n, e)};
    expect(texts.values, everyElement(isNotEmpty));
    expect(texts[NlError.contextExceeded], contains('too long'));
    expect(texts[NlError.unsupportedLocale], contains('language'));
  });
}
