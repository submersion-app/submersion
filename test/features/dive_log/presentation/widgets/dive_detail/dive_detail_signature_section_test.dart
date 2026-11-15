import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/fill_last_column.dart';

const _diveId = 'sig-dive';

final _alice = BuddyWithRole(
  buddy: Buddy(
    id: 'b1',
    name: 'Alice',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  roles: [DiveRole.builtInBuddy()],
);

/// Bumped to make the buddies read reload, as a dependency changing does.
class _Trigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final _trigger = NotifierProvider<_Trigger, int>(_Trigger.new);

Future<void> _pump(
  WidgetTester tester, {
  required bool buddies,
  required bool course,
  bool signaturesFail = false,
  double? height,
  Future<void> Function()? reloadGate,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.reset);

  final dive = Dive(
    id: _diveId,
    dateTime: DateTime(2026, 3, 15, 10),
    courseIds: course ? const ['c1'] : const [],
  );
  final section = DiveSignaturesSection(dive: dive);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        buddiesForDiveProvider(_diveId).overrideWith((ref) async {
          if (ref.watch(_trigger) > 0) await reloadGate?.call();
          return buddies ? [_alice] : <BuddyWithRole>[];
        }),
        buddySignaturesForDiveProvider(_diveId).overrideWith(
          (ref) async =>
              signaturesFail ? throw StateError('read failed') : <Signature>[],
        ),
        signatureForDiveProvider(_diveId).overrideWith((ref) async => null),
        coursesForDiveProvider(_diveId).overrideWith((ref) async => <Course>[]),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                key: const ValueKey('host'),
                width: 400,
                height: height,
                child: section,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _host(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('host')));

/// The outermost cards the section draws, top to bottom.
List<Rect> _cards(WidgetTester tester) {
  final rects = {
    for (final element in find.byType(Card).evaluate())
      (element.renderObject! as RenderBox).paintBounds.shift(
        (element.renderObject! as RenderBox).localToGlobal(Offset.zero),
      ),
  };
  bool inside(Rect inner, Rect outer) =>
      inner != outer && outer.intersect(inner) == inner;
  return [
    for (final rect in rects)
      if (!rects.any((other) => inside(rect, other))) rect,
  ]..sort((a, b) => a.top.compareTo(b.top));
}

void main() {
  testWidgets('with buddies and no course, one card grows to the height', (
    tester,
  ) async {
    await _pump(tester, buddies: true, course: false, height: 500);

    final cards = _cards(tester);
    expect(cards, hasLength(1));
    expect(cards.single.top, _host(tester).top);
    expect(cards.single.bottom, _host(tester).bottom);
  });

  // The empty buddy slot used to leave its 24px gap above the instructor's
  // card, so beside Buddies it started lower than the card next to it.
  testWidgets('with a course and no buddies, the card starts at the top', (
    tester,
  ) async {
    await _pump(tester, buddies: false, course: true);

    final cards = _cards(tester);
    expect(cards, hasLength(1));
    expect(cards.single.top, _host(tester).top);
  });

  testWidgets('when the buddy signatures fail to load, no gap is left', (
    tester,
  ) async {
    await _pump(tester, buddies: true, course: true, signaturesFail: true);

    final cards = _cards(tester);
    expect(cards, hasLength(1));
    expect(cards.single.top, _host(tester).top);
  });

  // A reload driven by a dependency keeps the last answer: no buddies. Read
  // as "still loading", it would bring in the buddy placeholder and its gap
  // above the instructor's card, then take them out again.
  testWidgets('a training dive without buddies holds still while they reload', (
    tester,
  ) async {
    final reload = Completer<void>();
    await _pump(
      tester,
      buddies: false,
      course: true,
      reloadGate: () => reload.future,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveSignaturesSection)),
    );

    container.read(_trigger.notifier).bump();
    await tester.pump();

    final cards = _cards(tester);
    expect(cards, hasLength(1));
    expect(cards.single.top, _host(tester).top);

    reload.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('with both, the last card takes the extra height', (
    tester,
  ) async {
    await _pump(tester, buddies: true, course: true, height: 900);

    expect(find.byType(FillLastColumn), findsOneWidget);
    final cards = _cards(tester);
    expect(cards, hasLength(2));
    expect(cards.first.top, _host(tester).top);
    expect(cards.last.bottom, _host(tester).bottom);
  });

  testWidgets('at its natural height, both cards stack 24px apart', (
    tester,
  ) async {
    await _pump(tester, buddies: true, course: true);

    final cards = _cards(tester);
    expect(cards, hasLength(2));
    expect(cards.last.top - cards.first.bottom, greaterThanOrEqualTo(24));
  });
}
