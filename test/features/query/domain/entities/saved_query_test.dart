import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/domain/entities/saved_query.dart';

void main() {
  final q = SavedQuery(
    id: 'q1',
    diverId: 'me',
    subject: 'dives',
    name: 'Deep',
    queryJson: '{"version":1,"node":{}}',
    createdAt: DateTime(2026, 9, 26),
    updatedAt: DateTime(2026, 9, 26),
  );

  test('value equality and copyWith', () {
    expect(q, q.copyWith());
    expect(q.hashCode, q.copyWith().hashCode);
    expect(q.copyWith(name: 'Deeper').name, 'Deeper');
    expect(q.copyWith(name: 'Deeper'), isNot(q));
    expect(q.copyWith(clearDiverId: true).diverId, isNull);
  });

  test('querySubject parses known names and tolerates unknown ones', () {
    expect(q.querySubject, QuerySubject.dives);
    expect(q.copyWith(subject: 'starships').querySubject, isNull);
  });
}
