import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

final _notes = EditField<String, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r,
  write: (r, v) => v,
);

void main() {
  late List<bool> prevented;
  late AppExitGuard guard;
  late RecordEditController<String> controller;
  late int asked;
  late bool answer;
  late RecordSittingExitBlocker<String> blocker;

  setUp(() {
    prevented = [];
    guard = AppExitGuard(
      retryExit: () async {},
      preventWindowClose: (prevent) async => prevented.add(prevent),
      revealWindow: () async {},
    );
    controller = RecordEditController<String>(onSave: (_) async {});
    asked = 0;
    answer = false;
    blocker = RecordSittingExitBlocker<String>(
      controller: controller,
      guard: guard,
      confirm: () async {
        asked++;
        return answer;
      },
    );
  });
  tearDown(() {
    blocker.dispose();
    controller.dispose();
  });

  test('holds while unlocked, releases on lock', () async {
    expect(prevented, isEmpty);
    controller.unlock('a');
    expect(prevented, [true]);
    controller.lock();
    expect(prevented, [true, false]);
  });

  test('releases on dispose', () {
    controller.unlock('a');
    blocker.dispose();
    expect(prevented, [true, false]);
  });

  test('a sitting with unsaved changes is asked about', () async {
    controller.unlock('a');
    controller.session!.set(_notes, 'b');

    expect(await guard.mayLeave(), isFalse);
    expect(asked, 1);

    answer = true;
    expect(await guard.mayLeave(), isTrue);
  });

  test(
    'leaving another page passes a sitting by; leaving its own asks',
    () async {
      final onPage = RecordSittingExitBlocker<String>(
        controller: controller,
        guard: guard,
        confirm: () async {
          asked++;
          return answer;
        },
        page: () => 'list',
      );
      addTearDown(onPage.dispose);
      blocker.dispose();
      controller.unlock('a');
      controller.session!.set(_notes, 'b');

      expect(await guard.mayLeave(page: 'pushed'), isTrue);
      expect(asked, 0);

      expect(await guard.mayLeave(page: 'list'), isFalse);
      expect(asked, 1);
      // A quit, or a leaving with no page, still asks about it.
      expect(await guard.mayLeave(), isFalse);
      expect(asked, 2);
    },
  );

  test('a clean sitting is no unsaved work', () async {
    controller.unlock('a');

    expect(await guard.mayLeave(), isTrue);
    expect(asked, 0);
  });
}
