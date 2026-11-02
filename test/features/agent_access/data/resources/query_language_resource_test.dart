import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/agent_access/data/resources/query_language_resource.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  group('QueryLanguageResource', () {
    test('has the documented uri and a markdown mime type', () {
      final r = QueryLanguageResource();
      expect(r.uri, 'submersion://query-language');
      expect(r.mimeType, 'text/markdown');
      expect(r.name, isNotEmpty);
    });

    test('lists every root and every dive field', () async {
      final text = await QueryLanguageResource().read(ctx());
      for (final root in QuerySubject.values.take(9)) {
        expect(text, contains('## ${root.name}'), reason: root.name);
      }
      expect(text, contains('- depth'));
      expect(text, contains('- waterTemp'));
      expect(text, contains('aliases: temp'));
      expect(text, contains('- site ->'));
    });

    test('carries the grammar and the units rule', () async {
      final text = await QueryLanguageResource().read(ctx());
      expect(text, contains('query      := or'));
      expect(text, contains(':none'));
      expect(text, contains('list_divers'));
      expect(text, contains('local wall clock'));
    });

    test('does not list child-only subjects as roots', () async {
      final text = await QueryLanguageResource().read(ctx());
      expect(text, isNot(contains('## tags')));
      expect(text, isNot(contains('## tanks')));
    });
  });
}
