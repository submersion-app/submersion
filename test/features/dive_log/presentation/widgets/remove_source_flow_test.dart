import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/services/dive_source_removal_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/remove_source_flow.dart';

import '../../../../helpers/test_app.dart';

class _FakeRemoval implements DiveSourceRemovalService {
  _FakeRemoval({
    this.shares = false,
    this.sharesThrows = false,
    this.removeThrows = false,
  });

  final bool shares;
  final bool sharesThrows;
  final bool removeThrows;
  final removed = <String>[];

  @override
  Future<bool> sharesComputer({
    required String diveId,
    required String sourceId,
  }) async {
    if (sharesThrows) throw StateError('database is locked');
    return shares;
  }

  @override
  Future<SourceRemoval> remove({
    required String diveId,
    required String sourceId,
  }) async {
    if (removeThrows) throw StateError('database is locked');
    removed.add(sourceId);
    return const SourceRemoval(operationId: 'op-1');
  }
}

/// The Remove source flow the dive page and the inbox share (issue #4393).
void main() {
  late _FakeRemoval removal;
  late int changes;
  late List<String> hooks;

  Future<void> pump(
    WidgetTester tester, {
    Future<void> Function()? onRemoved,
    Future<void> Function()? onUndone,
    Future<bool> Function(String operationId)? undo,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          diveSourceRemovalServiceProvider.overrideWithValue(removal),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => removeSourceWithUndo(
              context,
              ref,
              diveId: 'd1',
              sourceId: 's2',
              sourceName: 'Perdix 2',
              afterChange: () => changes++,
              onRemoved: onRemoved,
              onUndone: onUndone,
              undo: undo ?? (_) async => true,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    changes = 0;
    hooks = [];
  });

  testWidgets('a shared computer is explained, never confirmed', (
    tester,
  ) async {
    removal = _FakeRemoval(shares: true);
    await pump(tester);

    expect(find.text('Remove this source?'), findsNothing);
    expect(
      find.textContaining('shares its dive computer with another source'),
      findsOneWidget,
    );
    expect(removal.removed, isEmpty);
  });

  testWidgets('a failing preflight says the removal failed', (tester) async {
    removal = _FakeRemoval(sharesThrows: true);
    await pump(tester);

    expect(find.text('Could not remove the source'), findsOneWidget);
    expect(removal.removed, isEmpty);
  });

  testWidgets('a removal that throws says it failed and runs no hook', (
    tester,
  ) async {
    removal = _FakeRemoval(removeThrows: true);
    await pump(tester, onRemoved: () async => hooks.add('removed'));
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Could not remove the source'), findsOneWidget);
    expect(hooks, isEmpty);
    expect(changes, 0);
  });

  testWidgets('a confirmed removal runs the hooks and offers Undo', (
    tester,
  ) async {
    removal = _FakeRemoval();
    await pump(
      tester,
      onRemoved: () async => hooks.add('removed'),
      onUndone: () async => hooks.add('undone'),
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(removal.removed, ['s2']);
    expect(hooks, ['removed']);
    expect(changes, 1);
    expect(find.text('Source removed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(hooks, ['removed', 'undone']);
    expect(changes, 2);
  });

  testWidgets('a failing hook after the removal still offers Undo', (
    tester,
  ) async {
    removal = _FakeRemoval();
    await pump(
      tester,
      onRemoved: () async => throw StateError('database is locked'),
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(removal.removed, ['s2']);
    expect(find.text('Source removed'), findsOneWidget);
    expect(find.text('Could not remove the source'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('an Undo that leaves records behind says so', (tester) async {
    removal = _FakeRemoval();
    await pump(
      tester,
      onUndone: () async => throw StateError('database is locked'),
      undo: (_) async => false,
    );
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Undo could not put everything back'),
      findsOneWidget,
    );
  });
}
