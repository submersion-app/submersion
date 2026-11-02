import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_import/data/services/parsed_profile_event_mapper.dart';

/// The parsed-event mapper keeps an annotation's own id and user source
/// across a UDDF backup (#4109), and still mints ids for files without them.
void main() {
  final now = DateTime(2026, 11, 1);

  List<dynamic> map(Map<String, dynamic> m) =>
      profileEventsFromParsed(diveId: 'd1', eventMaps: [m], now: now);

  test('a file without id or source still imports as before', () {
    final e = map({'eventType': 'bookmark', 'timestamp': 30}).single;
    expect(e.id, hasLength(36));
    expect(e.source, EventSource.imported);
    expect(e.eventType, ProfileEventType.bookmark);
  });

  test(
    'an annotation keeps its id, words and depth, and stays the user\'s',
    () {
      final e = map({
        'eventType': 'annotation',
        'timestamp': 600,
        'id': 'ann-1',
        'source': 'user',
        'description': 'felt sick',
        'depth': 19.6,
      }).single;
      expect(e.id, 'ann-1');
      expect(e.eventType, ProfileEventType.annotation);
      expect(e.source, EventSource.user);
      expect(e.description, 'felt sick');
      expect(e.depth, 19.6);
      expect(e.timestamp, 600);
    },
  );

  test('an annotation without an id gets a fresh one', () {
    final e = map({'eventType': 'annotation', 'timestamp': 600}).single;
    expect(e.id, hasLength(36));
    expect(e.description, '');
  });

  test('a user-authored row of any type keeps its user source', () {
    final e = map({
      'eventType': 'bookmark',
      'timestamp': 30,
      'id': 'b-1',
      'source': 'user',
    }).single;
    expect(e.source, EventSource.user);
  });

  test('any other event keeps a given id too', () {
    final e = map({'eventType': 'bookmark', 'timestamp': 30, 'id': 'b-1'});
    expect(e.single.id, 'b-1');
    expect(e.single.source, EventSource.imported);
  });
}
