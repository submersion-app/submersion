import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/writes/change_set.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

Matcher _refused(String messagePart) => isA<AgentToolException>()
    .having((e) => e.code, 'code', AgentToolErrorCode.invalidArgument)
    .having((e) => e.message, 'message', contains(messagePart));

Map<String, Object?> _set(List<Object?> operations) => {
  'label': 'Fix buddy names',
  'operations': operations,
};

void main() {
  test('reads a create, an update and a delete in order', () {
    final set = ChangeSet.parse(
      _set([
        {
          'op': 'create',
          'entity': 'buddies',
          'diver_id': 'diver-1',
          'fields': {'name': 'Ana'},
        },
        {
          'op': 'update',
          'entity': 'dives',
          'id': 'd1',
          'fields': {'water_temp_c': 24.5, 'notes': null},
          'relations': {
            'tags': {
              'add': ['t1'],
              'remove': ['t2'],
            },
            'site': {
              'set': ['s1'],
            },
          },
        },
        {'op': 'delete', 'entity': 'sites', 'id': 's2'},
      ]),
    );

    expect(set.label, 'Fix buddy names');
    expect(set.operations, hasLength(3));
    final create = set.operations[0] as CreateOp;
    expect(create.entity, 'buddies');
    expect(create.diverId, 'diver-1');
    expect(create.fields, {'name': 'Ana'});
    final update = set.operations[1] as UpdateOp;
    expect(update.index, 1);
    expect(update.fields.containsKey('notes'), isTrue);
    expect(update.fields['notes'], isNull);
    expect(update.relations['tags']!.add, ['t1']);
    expect(update.relations['tags']!.remove, ['t2']);
    expect(update.relations['tags']!.set, isNull);
    expect(update.relations['site']!.set, ['s1']);
    expect((set.operations[2] as DeleteOp).id, 's2');
  });

  test('refuses an empty label', () {
    expect(
      () => ChangeSet.parse({
        'label': '   ',
        'operations': [
          {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
        ],
      }),
      throwsA(_refused('label')),
    );
  });

  test('refuses an empty change set', () {
    expect(() => ChangeSet.parse(_set([])), throwsA(_refused('operations')));
  });

  test('refuses more than 500 operations', () {
    final operations = [
      for (var i = 0; i <= kMaxChangeSetOperations; i++)
        {'op': 'delete', 'entity': 'dives', 'id': 'd$i'},
    ];
    expect(() => ChangeSet.parse(_set(operations)), throwsA(_refused('500')));
  });

  test('a relation with set and add is refused', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {
            'op': 'update',
            'entity': 'dives',
            'id': 'd1',
            'relations': {
              'tags': {
                'set': ['t1'],
                'add': ['t2'],
              },
            },
          },
        ]),
      ),
      throwsA(_refused('set')),
    );
  });

  test('an id both added and removed is refused, not guessed at', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {
            'op': 'update',
            'entity': 'dives',
            'id': 'd1',
            'relations': {
              'buddies': {
                'add': ['b1', 'b2'],
                'remove': ['b1'],
              },
            },
          },
        ]),
      ),
      throwsA(_refused('b1')),
    );
  });

  test('a relation key it does not take is refused', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {
            'op': 'update',
            'entity': 'dives',
            'id': 'd1',
            'relations': {
              'tags': {
                'replace': ['t1'],
              },
            },
          },
        ]),
      ),
      throwsA(_refused('replace')),
    );
  });

  test('a null set is refused rather than clearing every link', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {
            'op': 'update',
            'entity': 'dives',
            'id': 'd1',
            'relations': {
              'tags': {'set': null},
            },
          },
        ]),
      ),
      throwsA(_refused('set')),
    );
  });

  test('a label over its limit is refused', () {
    expect(
      () => ChangeSet.parse({
        'label': 'x' * (kMaxChangeSetLabelLength + 1),
        'operations': [
          {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
        ],
      }),
      throwsA(_refused('label')),
    );
  });

  test('an update with nothing to change is refused', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {'op': 'update', 'entity': 'dives', 'id': 'd1'},
        ]),
      ),
      throwsA(_refused('nothing')),
    );
  });

  test('names the failing operation index', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {'op': 'delete', 'entity': 'dives', 'id': 'd1'},
          {'op': 'merge', 'entity': 'dives', 'id': 'd2'},
        ]),
      ),
      throwsA(
        isA<AgentToolException>().having(
          (e) => e.details?['operation'],
          'operation',
          1,
        ),
      ),
    );
  });

  test('an operation with a key it does not take is refused', () {
    expect(
      () => ChangeSet.parse(
        _set([
          {
            'op': 'delete',
            'entity': 'dives',
            'id': 'd1',
            'fields': {'name': 'x'},
          },
        ]),
      ),
      throwsA(_refused('fields')),
    );
  });
}
