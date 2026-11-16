import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/my_role_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The My role card on Insights > Social (#4409).
void main() {
  final epoch = DateTime(2020);
  final roles = {
    'instructor': DiveRole(
      id: 'instructor',
      name: 'Instructor',
      isBuiltIn: true,
      createdAt: epoch,
      updatedAt: epoch,
    ),
    'r1': DiveRole(
      id: 'r1',
      diverId: 'me',
      name: 'Cave Guide',
      createdAt: epoch,
      updatedAt: epoch,
    ),
  };
  final segments = [
    DistributionSegment(
      label: 'instructor',
      count: 4,
      percentage: 50,
      totalDurationSeconds: 3600,
    ),
    DistributionSegment(
      label: 'r1',
      count: 3,
      percentage: 37.5,
      totalDurationSeconds: 1800,
    ),
    DistributionSegment(
      label: kNotRecordedDistributionKey,
      count: 1,
      percentage: 12.5,
      totalDurationSeconds: 600,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required Future<List<DistributionSegment>> Function() load,
    Locale locale = const Locale('en'),
    void Function(String key, String label)? onOpen,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diverRoleDistributionProvider.overrideWith((ref) => load()),
          diveRoleMapProvider.overrideWith((ref) async => roles),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: MyRoleCard(onOpen: onOpen)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a bar per role and Not set, in the diver\'s language', (
    tester,
  ) async {
    final de = lookupAppLocalizations(const Locale('de'));
    await pump(tester, load: () async => segments, locale: const Locale('de'));
    expect(find.text(de.insights_social_myRole_title), findsOneWidget);
    expect(find.text(de.diveRole_builtin_instructor), findsOneWidget);
    expect(find.text('Cave Guide'), findsOneWidget);
    expect(find.text(de.insights_social_myRole_notSet), findsOneWidget);
  });

  testWidgets('tapping a bar opens its dives', (tester) async {
    final opened = <String>[];
    await pump(
      tester,
      load: () async => segments,
      onOpen: (key, label) => opened.add('$key=$label'),
    );
    await tester.tap(find.text('Cave Guide'));
    await tester.tap(find.text('Not set'));
    expect(opened, ['r1=Cave Guide', '$kNotRecordedDistributionKey=Not set']);
  });

  testWidgets('a load in flight shows progress', (tester) async {
    final pending = Completer<List<DistributionSegment>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diverRoleDistributionProvider.overrideWith((ref) => pending.future),
          diveRoleMapProvider.overrideWith((ref) async => roles),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MyRoleCard()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('no dives shows the empty message', (tester) async {
    await pump(tester, load: () async => const []);
    expect(find.text('No dive data available'), findsOneWidget);
  });

  testWidgets('a failed load shows the error message', (tester) async {
    await pump(tester, load: () async => throw StateError('boom'));
    expect(find.text('Failed to load role data'), findsOneWidget);
  });
}
