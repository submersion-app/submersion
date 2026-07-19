import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/formatters/no_fly_format.dart';
import 'package:submersion/features/safety/presentation/pages/safety_hub_page.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, NoFlyStatus? status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noFlyStatusProvider.overrideWith((ref) async => status)],
        // Pin English so the asserted UI strings do not depend on the host
        // environment's locale.
        child: localizedMaterialApp(
          home: const SafetyHubPage(),
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows all-clear when no restriction', (tester) async {
    await pump(tester, null);
    expect(find.text('No flying restriction'), findsOneWidget);
  });

  testWidgets('shows a loading placeholder before the status resolves', (
    tester,
  ) async {
    final pending = Completer<NoFlyStatus?>();
    addTearDown(() => pending.complete(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [noFlyStatusProvider.overrideWith((ref) => pending.future)],
        child: localizedMaterialApp(
          home: const SafetyHubPage(),
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pump();
    // Never implies "no restriction" while still loading.
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('No flying restriction'), findsNothing);
  });

  testWidgets('shows an error placeholder when the status fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noFlyStatusProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
        child: localizedMaterialApp(
          home: const SafetyHubPage(),
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('No flying restriction'), findsNothing);
  });

  testWidgets('shows countdown for an active restriction', (tester) async {
    final status = NoFlyStatus(
      until: DateTime.now().toUtc().add(const Duration(hours: 10)),
      category: NoFlyCategory.repetitive,
      interval: const Duration(hours: 18),
    );
    await pump(tester, status);
    expect(find.textContaining('No-fly:'), findsOneWidget);
    expect(find.textContaining('repetitive dives: 18 h'), findsOneWidget);
    expect(find.textContaining('Not a substitute'), findsOneWidget);
  });

  testWidgets('shows the deco-dive guideline category', (tester) async {
    final status = NoFlyStatus(
      until: DateTime.now().toUtc().add(const Duration(hours: 20)),
      category: NoFlyCategory.deco,
      interval: const Duration(hours: 24),
    );
    await pump(tester, status);
    expect(find.textContaining('decompression dive: 24 h'), findsOneWidget);
  });

  test('formatNoFlyRemaining formats hours and minutes', () {
    expect(
      formatNoFlyRemaining(const Duration(hours: 14, minutes: 20)),
      '14h 20m',
    );
    expect(formatNoFlyRemaining(const Duration(minutes: 45)), '45min');
  });

  test(
    'formatNoFlyRemaining shows <1min for a positive sub-minute remainder',
    () {
      expect(formatNoFlyRemaining(const Duration(seconds: 30)), '<1min');
      expect(formatNoFlyRemaining(Duration.zero), '0min');
    },
  );
}
