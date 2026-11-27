import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/presentation/providers/emergency_tag_providers.dart';

class _RecordingDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _RecordingDiverListNotifier() : super(const AsyncValue.data([]));

  final updated = <Diver>[];

  @override
  Future<void> updateDiver(Diver diver) async => updated.add(diver);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final diver = Diver(
    id: 'd1',
    name: 'Sam Diver',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const call = EmergencyTagChoices(
    primary: EmergencyTagPrimary.call,
    callTarget: EmergencyCallTarget.insurer,
    fields: {EmergencyTagField.allergies},
    includeText: true,
  );

  test('the current diver with no stored choices gets the defaults', () async {
    final container = ProviderContainer(
      overrides: [currentDiverProvider.overrideWith((ref) async => diver)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(myEmergencyTagChoicesProvider.future),
      EmergencyTagChoices.defaults,
    );
  });

  test('stored choices are read from the diver row', () async {
    final stored = withEmergencyTagChoices(diver, call);
    final container = ProviderContainer(
      overrides: [currentDiverProvider.overrideWith((ref) async => stored)],
    );
    addTearDown(container.dispose);
    expect(await container.read(myEmergencyTagChoicesProvider.future), call);
  });

  Future<WidgetRef> refIn(WidgetTester tester, List<Object> overrides) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('saving stores the choices on the current diver', (tester) async {
    final notifier = _RecordingDiverListNotifier();
    final ref = await refIn(tester, [
      currentDiverProvider.overrideWith((ref) async => diver),
      diverListNotifierProvider.overrideWith((ref) => notifier),
    ]);
    await tester.runAsync(() => saveMyEmergencyTagChoices(ref, call));
    expect(notifier.updated.single.id, 'd1');
    expect(
      EmergencyTagChoices.fromJson(notifier.updated.single.emergencyTagShare),
      call,
    );
  });

  testWidgets('saving with no current diver stores nothing', (tester) async {
    final notifier = _RecordingDiverListNotifier();
    final ref = await refIn(tester, [
      currentDiverProvider.overrideWith((ref) async => null),
      diverListNotifierProvider.overrideWith((ref) => notifier),
    ]);
    await tester.runAsync(() => saveMyEmergencyTagChoices(ref, call));
    expect(notifier.updated, isEmpty);
  });
}
