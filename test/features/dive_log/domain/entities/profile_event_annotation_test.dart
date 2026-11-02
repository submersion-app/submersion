import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';

/// Annotations (#4109): a user-authored profile event whose words live in
/// the dive's Notes. The entity, its string mapping and the 3D view's
/// bookmark pass all recognise the new type.
void main() {
  test('annotation factory is user-authored with the words as description', () {
    final e = ProfileEvent.annotation(
      id: 'a1',
      diveId: 'd1',
      timestamp: 1290,
      depth: 19.6,
      words: 'started feeling nauseous',
      createdAt: DateTime(2026),
    );
    expect(e.eventType, ProfileEventType.annotation);
    expect(e.source, EventSource.user);
    expect(e.description, 'started feeling nauseous');
    expect(e.depth, 19.6);
    expect(e.timestamp, 1290);
    expect(e.isAnnotation, isTrue);
    expect(ProfileEventType.annotation.iconName, 'push_pin');
    expect(ProfileEventType.annotation.defaultSeverity, 'info');
  });

  test('a computer event is not an annotation', () {
    final e = ProfileEvent.bookmark(
      id: 'b1',
      diveId: 'd1',
      timestamp: 10,
      createdAt: DateTime(2026),
    );
    expect(e.isAnnotation, isFalse);
  });

  test('the string mapper reads annotation back by name', () {
    const row = DiveProfileEvent(
      id: 'a1',
      diveId: 'd1',
      timestamp: 1290,
      eventType: 'annotation',
      severity: 'info',
      description: 'felt sick',
      depth: 19.6,
      value: null,
      tankId: null,
      source: 'user',
      createdAt: 1700000000000,
    );
    final e = mapDiveProfileEventToProfileEvent(row);
    expect(e.eventType, ProfileEventType.annotation);
    expect(e.source, EventSource.user);
    expect(e.isAnnotation, isTrue);
  });

  test('the 3D scene counts annotations among bookmark events', () {
    final data = Dive3dSceneData.fromDomain(
      diveId: 'd1',
      points: const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 60, depth: 18),
      ],
      tankPressures: const {},
      gasSwitches: const [],
      events: [
        ProfileEvent.annotation(
          id: 'a1',
          diveId: 'd1',
          timestamp: 30,
          words: 'octo free-flow',
          createdAt: DateTime(2026),
        ),
      ],
      photos: const [],
    );
    expect(data.bookmarkEvents, hasLength(1));
  });
}
