import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
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
    expect(notifier.state.editKinds, [ProfileEditorEditKinds.smoothAll]);
  });

  test('combines multiple edit kinds into revision token', () {
    notifier.setSelectedRange(start: 8, end: 24);
    notifier.shiftSegmentDepth(1.0);
    notifier.applySmoothingToRange(windowSize: 3);

    expect(
      notifier.state.revisionEditKindToken,
      'shift_depth+smooth_selection',
    );
  });

  test('undo restores previous state', () {
    final before = notifier.state.editedProfile;
    notifier.applySmoothing(windowSize: 5);
    expect(notifier.state.editKinds, [ProfileEditorEditKinds.smoothAll]);
    expect(notifier.state.editedProfile, isNot(equals(before)));
    notifier.undo();
    expect(notifier.state.editedProfile, before);
    expect(notifier.state.undoStack, isEmpty);
    expect(notifier.state.editKinds, isEmpty);
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

  group('range edits (issue #3909)', () {
    /// A dive with a gap around the selection, room for a time shift to land.
    ProfileEditorNotifier gappedNotifier() => ProfileEditorNotifier(
      originalProfile: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 60, depth: 10),
        DiveProfilePoint(timestamp: 70, depth: 12),
        DiveProfilePoint(timestamp: 130, depth: 0),
      ],
      editingService: ProfileEditingService(),
    );

    test('a time shift moves the selection with its samples', () {
      final gapped = gappedNotifier()..setSelectedRange(start: 60, end: 70);

      expect(gapped.shiftSegmentTime(5), isTrue);

      expect(gapped.state.selectedRange, (start: 65, end: 75));
      expect(gapped.state.editedProfile.map((p) => p.timestamp), [
        0,
        65,
        75,
        130,
      ]);
    });

    test('repeating a time shift keeps moving the same samples', () {
      final gapped = gappedNotifier()..setSelectedRange(start: 60, end: 70);

      gapped
        ..shiftSegmentTime(5)
        ..shiftSegmentTime(5);

      expect(gapped.state.editedProfile.map((p) => p.timestamp), [
        0,
        70,
        80,
        130,
      ]);
    });

    test('a time shift that would overlap reports it and changes nothing', () {
      notifier.setSelectedRange(start: 8, end: 24);
      final before = notifier.state;

      expect(notifier.shiftSegmentTime(5), isFalse);

      expect(notifier.state, before);
    });

    test('undoing a time shift puts the selection back', () {
      final gapped = gappedNotifier()..setSelectedRange(start: 60, end: 70);

      gapped
        ..shiftSegmentTime(5)
        ..undo();

      expect(gapped.state.selectedRange, (start: 60, end: 70));
    });

    test('undoing a delete brings back the selection it removed', () {
      notifier
        ..setSelectedRange(start: 8, end: 24)
        ..deleteSegment();
      expect(notifier.state.selectedRange, isNull);

      notifier.undo();

      expect(notifier.state.selectedRange, (start: 8, end: 24));
    });

    test('undoing an edit made with no selection leaves none', () {
      notifier
        ..applySmoothing()
        ..setSelectedRange(start: 8, end: 24)
        ..undo();

      expect(notifier.state.selectedRange, isNull);
    });

    test('a delete that leaves samples reports success', () {
      notifier.setSelectedRange(start: 8, end: 24);

      expect(notifier.deleteSegment(interpolateGap: true), isTrue);

      expect(notifier.state.editedProfile, isNotEmpty);
      expect(notifier.state.hasChanges, isTrue);
    });

    for (final interpolateGap in [false, true]) {
      test('a delete of every sample is refused, '
          'interpolateGap: $interpolateGap', () {
        notifier.setSelectedRange(start: 0, end: 76);
        final before = notifier.state;

        expect(notifier.deleteSegment(interpolateGap: interpolateGap), isFalse);

        expect(notifier.state, before);
      });
    }

    test('generating a profile clears the selection of replaced samples', () {
      notifier
        ..setSelectedRange(start: 8, end: 24)
        ..addWaypoint(const ProfileWaypoint(timestamp: 0, depth: 0))
        ..addWaypoint(const ProfileWaypoint(timestamp: 40, depth: 10))
        ..generateProfileFromWaypoints();

      expect(notifier.state.selectedRange, isNull);
    });

    test('trimming clears a selection that may reach the removed tail', () {
      final tailed = ProfileEditorNotifier(
        originalProfile: const [
          DiveProfilePoint(timestamp: 0, depth: 10),
          DiveProfilePoint(timestamp: 60, depth: 0),
          DiveProfilePoint(timestamp: 120, depth: 0),
          DiveProfilePoint(timestamp: 180, depth: 0),
        ],
        editingService: ProfileEditingService(),
      )..setSelectedRange(start: 60, end: 180);

      tailed.trimEndZeros();

      expect(tailed.state.selectedRange, isNull);
    });

    group('edits that invalidate detected outliers', () {
      ProfileEditorNotifier detected() {
        final detecting = ProfileEditorNotifier(
          originalProfile: [
            for (var i = 0; i < 12; i++)
              DiveProfilePoint(
                timestamp: i * 10,
                depth: i >= 10 ? 0 : (i == 8 ? 90 : 10),
              ),
          ],
          editingService: ProfileEditingService(),
        );
        detecting.setSelectedRange(start: 10, end: 30);
        detecting.detectOutliers();
        expect(detecting.state.detectedOutliers, isNotEmpty);
        return detecting;
      }

      test('a delete renumbers the samples they point at', () {
        final editing = detected();
        expect(editing.deleteSegment(), isTrue);
        expect(editing.state.detectedOutliers, isNull);
      });

      test('a depth shift changes what they measured', () {
        final editing = detected()..shiftSegmentDepth(1);
        expect(editing.state.detectedOutliers, isNull);
      });

      test('smoothing changes what they measured', () {
        final editing = detected()..applySmoothing();
        expect(editing.state.detectedOutliers, isNull);
      });

      test('smoothing the selection changes what they measured', () {
        final editing = detected()..applySmoothingToRange();
        expect(editing.state.detectedOutliers, isNull);
      });

      test('a time shift moves them', () {
        final editing = detected();
        expect(editing.shiftSegmentTime(5), isTrue);
        expect(editing.state.detectedOutliers, isNull);
      });

      test('a trim drops samples', () {
        final editing = detected()..trimEndZeros();
        expect(editing.state.detectedOutliers, isNull);
      });

      test('a generated profile replaces the samples', () {
        final editing = detected()
          ..addWaypoint(const ProfileWaypoint(timestamp: 0, depth: 0))
          ..addWaypoint(const ProfileWaypoint(timestamp: 60, depth: 10))
          ..generateProfileFromWaypoints();
        expect(editing.state.detectedOutliers, isNull);
      });

      test('an undo goes back to another profile', () {
        final editing = detected()
          ..applySmoothing()
          ..undo();
        expect(editing.state.detectedOutliers, isNull);
      });
    });

    test('smoothing a selection of two samples records no edit', () {
      final editing = ProfileEditorNotifier(
        originalProfile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 60, depth: 20),
          DiveProfilePoint(timestamp: 120, depth: 0),
        ],
        editingService: ProfileEditingService(),
      );
      editing.setSelectedRange(start: 0, end: 60);

      expect(editing.applySmoothingToRange(), isFalse);

      expect(editing.state.undoStack, isEmpty);
      expect(editing.state.hasChanges, isFalse);
    });
  });

  group('trimEndZeros', () {
    test('is no-op for profiles shorter than two points', () {
      final shortNotifier = ProfileEditorNotifier(
        originalProfile: const [DiveProfilePoint(timestamp: 0, depth: 0.0)],
        editingService: ProfileEditingService(),
      );

      shortNotifier.trimEndZeros();

      expect(shortNotifier.state.editedProfile.length, 1);
      expect(shortNotifier.state.undoStack, isEmpty);
      expect(shortNotifier.state.hasChanges, isFalse);
    });

    test('trims trailing zeros, creates undo entry, and marks changes', () {
      final profileWithTrailingZeros = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 60, depth: 20.0),
        const DiveProfilePoint(timestamp: 120, depth: 0.0),
        const DiveProfilePoint(timestamp: 180, depth: 0.0),
        const DiveProfilePoint(timestamp: 240, depth: 0.0),
      ];
      final trimNotifier = ProfileEditorNotifier(
        originalProfile: profileWithTrailingZeros,
        editingService: ProfileEditingService(),
      );

      trimNotifier.trimEndZeros();

      expect(trimNotifier.state.editedProfile.length, 3);
      expect(trimNotifier.state.editedProfile.last.timestamp, 120);
      expect(trimNotifier.state.undoStack.length, 1);
      expect(trimNotifier.state.hasChanges, isTrue);
    });

    test('is no-op when profile does not change after trim', () {
      final profileWithoutExtraTrailingZeros = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 60, depth: 18.0),
        const DiveProfilePoint(timestamp: 120, depth: 0.0),
      ];
      final trimNotifier = ProfileEditorNotifier(
        originalProfile: profileWithoutExtraTrailingZeros,
        editingService: ProfileEditingService(),
      );

      trimNotifier.trimEndZeros();

      expect(
        trimNotifier.state.editedProfile,
        profileWithoutExtraTrailingZeros,
      );
      expect(trimNotifier.state.undoStack, isEmpty);
      expect(trimNotifier.state.hasChanges, isFalse);
    });
  });
}
