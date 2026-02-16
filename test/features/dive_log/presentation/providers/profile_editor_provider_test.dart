import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';

void main() {
  late ProfileEditorNotifier notifier;
  late List<DiveProfilePoint> testProfile;

  setUp(() {
    testProfile = List.generate(
      20,
      (i) => DiveProfilePoint(
        timestamp: i * 4,
        depth: i < 10 ? i * 2.0 : (20 - i) * 2.0,
      ),
    );
    notifier = ProfileEditorNotifier(
      originalProfile: testProfile,
      editingService: ProfileEditingService(),
    );
  });

  test('initial state has no changes', () {
    expect(notifier.state.hasChanges, isFalse);
    expect(notifier.state.editedProfile, testProfile);
    expect(notifier.state.mode, EditorMode.select);
    expect(notifier.state.undoStack, isEmpty);
  });

  test('setMode changes mode', () {
    notifier.setMode(EditorMode.smooth);
    expect(notifier.state.mode, EditorMode.smooth);
  });

  test('applySmoothing creates undo entry and marks changes', () {
    notifier.applySmoothing(windowSize: 3);
    expect(notifier.state.hasChanges, isTrue);
    expect(notifier.state.undoStack.length, 1);
  });

  test('undo restores previous state', () {
    final before = notifier.state.editedProfile;
    notifier.applySmoothing(windowSize: 5);
    expect(notifier.state.editedProfile, isNot(equals(before)));
    notifier.undo();
    expect(notifier.state.editedProfile, before);
    expect(notifier.state.undoStack, isEmpty);
  });

  test('undo when stack empty is no-op', () {
    notifier.undo();
    expect(notifier.state.editedProfile, testProfile);
  });

  test('detectOutliers stores results in state', () {
    notifier.detectOutliers();
    expect(notifier.state.detectedOutliers, isNotNull);
  });

  test('setSelectedRange stores range', () {
    notifier.setSelectedRange(start: 8, end: 40);
    expect(notifier.state.selectedRange, (start: 8, end: 40));
  });

  test('clearSelectedRange removes range', () {
    notifier.setSelectedRange(start: 8, end: 40);
    notifier.clearSelectedRange();
    expect(notifier.state.selectedRange, isNull);
  });
}
