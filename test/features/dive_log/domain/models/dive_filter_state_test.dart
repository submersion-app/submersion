import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Helper to create a minimal Dive for filter testing.
Dive _makeDive({
  String id = 'dive-1',
  DateTime? dateTime,
  double? maxDepth,
  String? diveTypeId,
  bool isFavorite = false,
  String? diveComputerSerial,
  String? computerId,
  int? rating,
  Duration? duration,
  String? tripId,
  List<DiveCustomField> customFields = const [],
  List<EquipmentItem> equipment = const [],
  List<DiveProfilePoint> profile = const [],
}) {
  return Dive(
    id: id,
    dateTime: dateTime ?? DateTime(2026, 3, 19),
    maxDepth: maxDepth,
    diveTypeIds: [diveTypeId ?? 'recreational'],
    isFavorite: isFavorite,
    diveComputerSerial: diveComputerSerial,
    computerId: computerId,
    rating: rating,
    bottomTime: duration,
    tripId: tripId,
    tanks: const [],
    profile: profile,
    equipment: equipment,
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
    customFields: customFields,
  );
}

/// Helper to build an equipment item carrying the given attributes.
EquipmentItem _makeEquipment(
  String id, {
  EquipmentType type = EquipmentType.wetsuit,
  List<EquipmentAttribute> attributes = const [],
}) {
  return EquipmentItem(
    id: id,
    name: 'Gear $id',
    type: type,
    attributes: attributes,
  );
}

void main() {
  group('DiveFilterState', () {
    group('constructor defaults', () {
      test('all fields default to null or empty', () {
        const filter = DiveFilterState();

        expect(filter.startDate, isNull);
        expect(filter.endDate, isNull);
        expect(filter.diveTypeId, isNull);
        expect(filter.siteId, isNull);
        expect(filter.tripId, isNull);
        expect(filter.diveCenterId, isNull);
        expect(filter.minDepth, isNull);
        expect(filter.maxDepth, isNull);
        expect(filter.favoritesOnly, isNull);
        expect(filter.decoOnly, isNull);
        expect(filter.noBuddyOnly, isNull);
        expect(filter.tagIds, isEmpty);
        expect(filter.weekdays, isEmpty);
        expect(filter.equipmentIds, isEmpty);
        expect(filter.buddyNameFilter, isNull);
        expect(filter.buddyId, isNull);
        expect(filter.diveIds, isEmpty);
        expect(filter.minO2Percent, isNull);
        expect(filter.maxO2Percent, isNull);
        expect(filter.minRating, isNull);
        expect(filter.minBottomTimeMinutes, isNull);
        expect(filter.maxBottomTimeMinutes, isNull);
        expect(filter.computerId, isNull);
        expect(filter.customFieldKey, isNull);
        expect(filter.customFieldValue, isNull);
      });
    });

    group('hasActiveFilters', () {
      test('returns false for default empty state', () {
        const filter = DiveFilterState();

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when computerId is set', () {
        const filter = DiveFilterState(computerId: 'computer-a');

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when startDate is set', () {
        final filter = DiveFilterState(startDate: DateTime(2026, 1, 1));

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when minRating is set', () {
        const filter = DiveFilterState(minRating: 3);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when minBottomTimeMinutes is set', () {
        const filter = DiveFilterState(minBottomTimeMinutes: 30);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when maxBottomTimeMinutes is set', () {
        const filter = DiveFilterState(maxBottomTimeMinutes: 60);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when customFieldKey is set and non-empty', () {
        const filter = DiveFilterState(customFieldKey: 'visibility');

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when customFieldKey is empty string', () {
        const filter = DiveFilterState(customFieldKey: '');

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when favoritesOnly is true', () {
        const filter = DiveFilterState(favoritesOnly: true);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when favoritesOnly is false', () {
        const filter = DiveFilterState(favoritesOnly: false);

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when decoOnly is true', () {
        const filter = DiveFilterState(decoOnly: true);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when decoOnly is false', () {
        const filter = DiveFilterState(decoOnly: false);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when noBuddyOnly is true', () {
        const filter = DiveFilterState(noBuddyOnly: true);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when noBuddyOnly is false', () {
        const filter = DiveFilterState(noBuddyOnly: false);

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when diveIds is non-empty', () {
        const filter = DiveFilterState(diveIds: ['d1', 'd2']);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when weekdays is non-empty', () {
        const filter = DiveFilterState(weekdays: [1, 3]);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when buddyNameFilter is set and non-empty', () {
        const filter = DiveFilterState(buddyNameFilter: 'John');

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when buddyNameFilter is empty string', () {
        const filter = DiveFilterState(buddyNameFilter: '');

        expect(filter.hasActiveFilters, isFalse);
      });
    });

    group('copyWith', () {
      test('sets computerId', () {
        const original = DiveFilterState();

        final updated = original.copyWith(computerId: 'computer-a');

        expect(updated.computerId, 'computer-a');
      });

      test('preserves computerId when not specified', () {
        const original = DiveFilterState(computerId: 'computer-a');

        final updated = original.copyWith(minRating: 3);

        expect(updated.computerId, 'computer-a');
        expect(updated.minRating, 3);
      });

      test('clears computerId with clearComputerId', () {
        const original = DiveFilterState(computerId: 'computer-a');

        final updated = original.copyWith(clearComputerId: true);

        expect(updated.computerId, isNull);
      });

      test('clearComputerId takes precedence over new value', () {
        const original = DiveFilterState(computerId: 'computer-a');

        final updated = original.copyWith(
          computerId: 'computer-b',
          clearComputerId: true,
        );

        expect(updated.computerId, isNull);
      });

      test('sets decoOnly', () {
        const original = DiveFilterState();

        final updated = original.copyWith(decoOnly: true);

        expect(updated.decoOnly, isTrue);
      });

      test('clears decoOnly with clearDecoOnly', () {
        const original = DiveFilterState(decoOnly: false);

        final updated = original.copyWith(clearDecoOnly: true);

        expect(updated.decoOnly, isNull);
      });

      test('sets noBuddyOnly', () {
        const original = DiveFilterState();

        final updated = original.copyWith(noBuddyOnly: true);

        expect(updated.noBuddyOnly, isTrue);
      });

      test('clears noBuddyOnly with clearNoBuddyOnly', () {
        const original = DiveFilterState(noBuddyOnly: true);

        final updated = original.copyWith(clearNoBuddyOnly: true);

        expect(updated.noBuddyOnly, isNull);
      });

      test('sets weekdays', () {
        const original = DiveFilterState();

        final updated = original.copyWith(weekdays: [1, 2]);

        expect(updated.weekdays, [1, 2]);
      });

      test('clears weekdays with clearWeekdays', () {
        const original = DiveFilterState(weekdays: [1, 2]);

        final updated = original.copyWith(clearWeekdays: true);

        expect(updated.weekdays, isEmpty);
      });

      test('sets and clears multiple fields simultaneously', () {
        const original = DiveFilterState(
          minRating: 3,
          computerId: 'computer-a',
          minBottomTimeMinutes: 30,
        );

        final updated = original.copyWith(
          clearMinRating: true,
          maxBottomTimeMinutes: 60,
          clearComputerId: true,
        );

        expect(updated.minRating, isNull);
        expect(updated.computerId, isNull);
        expect(updated.minBottomTimeMinutes, 30);
        expect(updated.maxBottomTimeMinutes, 60);
      });
    });

    group('apply', () {
      test('returns all dives when no filters are active', () {
        const filter = DiveFilterState();
        final dives = [_makeDive(id: 'd1'), _makeDive(id: 'd2')];

        final result = filter.apply(dives);

        expect(result, hasLength(2));
      });

      test('filters by computerId', () {
        const filter = DiveFilterState(computerId: 'computer-a');
        final dives = [
          _makeDive(id: 'd1', computerId: 'computer-a'),
          _makeDive(id: 'd2', computerId: 'computer-b'),
          _makeDive(id: 'd3'), // not attributed to any computer
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      // Issue #1064: computers whose firmware never reports a serial were
      // unfilterable. Attribution rides the computer id, never the serial.
      test('filters by computerId when the dives carry no serial', () {
        const filter = DiveFilterState(computerId: 'computer-a');
        final dives = [
          _makeDive(id: 'd1', computerId: 'computer-a'),
          _makeDive(id: 'd2', computerId: 'computer-a'),
          _makeDive(id: 'd3', computerId: 'computer-b'),
        ];

        final result = filter.apply(dives);

        expect(result.map((d) => d.id), ['d1', 'd2']);
      });

      test('filters by minRating', () {
        const filter = DiveFilterState(minRating: 3);
        final dives = [
          _makeDive(id: 'd1', rating: 5),
          _makeDive(id: 'd2', rating: 2),
          _makeDive(id: 'd3'), // null rating
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by minBottomTimeMinutes', () {
        const filter = DiveFilterState(minBottomTimeMinutes: 30);
        final dives = [
          _makeDive(id: 'd1', duration: const Duration(minutes: 45)),
          _makeDive(id: 'd2', duration: const Duration(minutes: 20)),
          _makeDive(id: 'd3'), // null duration
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by maxBottomTimeMinutes', () {
        const filter = DiveFilterState(maxBottomTimeMinutes: 30);
        final dives = [
          _makeDive(id: 'd1', duration: const Duration(minutes: 20)),
          _makeDive(id: 'd2', duration: const Duration(minutes: 45)),
          _makeDive(id: 'd3'), // null duration
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by both minBottomTimeMinutes and maxBottomTimeMinutes', () {
        const filter = DiveFilterState(
          minBottomTimeMinutes: 20,
          maxBottomTimeMinutes: 40,
        );
        final dives = [
          _makeDive(id: 'd1', duration: const Duration(minutes: 30)),
          _makeDive(id: 'd2', duration: const Duration(minutes: 10)),
          _makeDive(id: 'd3', duration: const Duration(minutes: 50)),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by customFieldKey', () {
        const filter = DiveFilterState(customFieldKey: 'visibility');
        final dives = [
          _makeDive(
            id: 'd1',
            customFields: [
              const DiveCustomField(
                id: 'cf1',
                key: 'visibility',
                value: 'good',
              ),
            ],
          ),
          _makeDive(id: 'd2'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by customFieldKey and customFieldValue', () {
        const filter = DiveFilterState(
          customFieldKey: 'visibility',
          customFieldValue: 'good',
        );
        final dives = [
          _makeDive(
            id: 'd1',
            customFields: [
              const DiveCustomField(
                id: 'cf1',
                key: 'visibility',
                value: 'good',
              ),
            ],
          ),
          _makeDive(
            id: 'd2',
            customFields: [
              const DiveCustomField(
                id: 'cf2',
                key: 'visibility',
                value: 'poor',
              ),
            ],
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('customFieldValue match is case-insensitive', () {
        const filter = DiveFilterState(
          customFieldKey: 'visibility',
          customFieldValue: 'GOOD',
        );
        final dives = [
          _makeDive(
            id: 'd1',
            customFields: [
              const DiveCustomField(
                id: 'cf1',
                key: 'visibility',
                value: 'Good',
              ),
            ],
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
      });

      test('filters by startDate and endDate', () {
        final filter = DiveFilterState(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
        );
        final dives = [
          _makeDive(id: 'd1', dateTime: DateTime(2026, 3, 15)),
          _makeDive(id: 'd2', dateTime: DateTime(2026, 2, 15)),
          _makeDive(id: 'd3', dateTime: DateTime(2026, 4, 15)),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      group('weekdays', () {
        test('filters by matching weekday', () {
          final monday = DateTime(2026, 3, 16);
          final tuesday = DateTime(2026, 3, 17);
          final filter = DiveFilterState(weekdays: [monday.weekday]);
          final dives = [
            _makeDive(id: 'd1', dateTime: monday),
            _makeDive(id: 'd2', dateTime: tuesday),
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), ['d1']);
        });

        test('matches ANY selected weekday', () {
          final monday = DateTime(2026, 3, 16);
          final tuesday = DateTime(2026, 3, 17);
          final wednesday = DateTime(2026, 3, 18);
          final filter = DiveFilterState(
            weekdays: [monday.weekday, wednesday.weekday],
          );
          final dives = [
            _makeDive(id: 'd1', dateTime: monday),
            _makeDive(id: 'd2', dateTime: tuesday),
            _makeDive(id: 'd3', dateTime: wednesday),
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), containsAll(['d1', 'd3']));
          expect(result, hasLength(2));
        });

        test('combines with date range as AND', () {
          final insideRangeMonday = DateTime(2026, 3, 16);
          final outsideRangeMonday = DateTime(2026, 4, 6);
          final insideRangeTuesday = DateTime(2026, 3, 17);
          final filter = DiveFilterState(
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 3, 31),
            weekdays: [insideRangeMonday.weekday],
          );
          final dives = [
            _makeDive(id: 'd1', dateTime: insideRangeMonday),
            _makeDive(id: 'd2', dateTime: outsideRangeMonday),
            _makeDive(id: 'd3', dateTime: insideRangeTuesday),
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), ['d1']);
        });
      });

      test('filters by diveIds', () {
        const filter = DiveFilterState(diveIds: ['d1', 'd3']);
        final dives = [
          _makeDive(id: 'd1'),
          _makeDive(id: 'd2'),
          _makeDive(id: 'd3'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(2));
        expect(result.map((d) => d.id), containsAll(['d1', 'd3']));
      });

      test('combines multiple filters', () {
        const filter = DiveFilterState(computerId: 'computer-a', minRating: 3);
        final dives = [
          _makeDive(id: 'd1', computerId: 'computer-a', rating: 5),
          _makeDive(id: 'd2', computerId: 'computer-a', rating: 2),
          _makeDive(id: 'd3', computerId: 'computer-b', rating: 5),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by favoritesOnly', () {
        const filter = DiveFilterState(favoritesOnly: true);
        final dives = [
          _makeDive(id: 'd1', isFavorite: true),
          _makeDive(id: 'd2', isFavorite: false),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by noBuddyOnly (excludes legacy and linked buddies)', () {
        const filter = DiveFilterState(noBuddyOnly: true);
        final buddyJohn = Buddy(
          id: 'b1',
          name: 'John Doe',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final dives = [
          Dive(id: 'd1', dateTime: DateTime.now(), notes: ''),
          Dive(
            id: 'd2',
            dateTime: DateTime.now(),
            buddy: 'Jane Smith',
            notes: '',
          ),
          Dive(
            id: 'd3',
            dateTime: DateTime.now(),
            notes: '',
            buddies: [
              BuddyWithRole(buddy: buddyJohn, role: DiveRole.builtInBuddy()),
            ],
          ),
          Dive(id: 'd4', dateTime: DateTime.now(), buddy: '', notes: ''),
        ];

        final result = filter.apply(dives);

        expect(result.map((d) => d.id), containsAll(['d1', 'd4']));
        expect(result, hasLength(2));
      });

      test('filters by depth range', () {
        const filter = DiveFilterState(minDepth: 10.0, maxDepth: 30.0);
        final dives = [
          _makeDive(id: 'd1', maxDepth: 20.0),
          _makeDive(id: 'd2', maxDepth: 5.0),
          _makeDive(id: 'd3', maxDepth: 40.0),
          _makeDive(id: 'd4'), // null depth
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by tripId', () {
        const filter = DiveFilterState(tripId: 'trip-1');
        final dives = [
          _makeDive(id: 'd1', tripId: 'trip-1'),
          _makeDive(id: 'd2', tripId: 'trip-2'),
          _makeDive(id: 'd3'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by diveTypeId', () {
        const filter = DiveFilterState(diveTypeId: 'technical');
        final dives = [
          _makeDive(id: 'd1', diveTypeId: 'technical'),
          _makeDive(id: 'd2', diveTypeId: 'recreational'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by buddyNameFilter (case-insensitive legacy)', () {
        const filter = DiveFilterState(buddyNameFilter: 'JOHN');
        final dives = [
          Dive(
            id: 'd1',
            dateTime: DateTime.now(),
            buddy: 'John Doe',
            notes: '',
          ),
          Dive(
            id: 'd2',
            dateTime: DateTime.now(),
            buddy: 'Jane Smith',
            notes: '',
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by buddyNameFilter (case-insensitive structured)', () {
        const filter = DiveFilterState(buddyNameFilter: 'doe');
        final buddyJohn = Buddy(
          id: 'b1',
          name: 'John Doe',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final dives = [
          Dive(
            id: 'd1',
            dateTime: DateTime.now(),
            notes: '',
            buddies: [
              BuddyWithRole(buddy: buddyJohn, role: DiveRole.builtInBuddy()),
            ],
          ),
          Dive(
            id: 'd2',
            dateTime: DateTime.now(),
            buddy: 'Jane Doe',
            notes: '',
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(2));
      });

      test('filters by multiple comma-separated buddies (AND-semantics)', () {
        const filter = DiveFilterState(buddyNameFilter: 'John, Jane');
        final buddyJohn = Buddy(
          id: 'b1',
          name: 'John Smith',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final buddyJane = Buddy(
          id: 'b2',
          name: 'Jane Smith',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final dives = [
          // D1: Matches both (John in structured, Jane in legacy)
          Dive(
            id: 'd1',
            dateTime: DateTime.now(),
            buddy: 'Jane Doe',
            notes: '',
            buddies: [
              BuddyWithRole(buddy: buddyJohn, role: DiveRole.builtInBuddy()),
            ],
          ),
          // D2: Matches both (Both in structured)
          Dive(
            id: 'd2',
            dateTime: DateTime.now(),
            notes: '',
            buddies: [
              BuddyWithRole(buddy: buddyJohn, role: DiveRole.builtInBuddy()),
              BuddyWithRole(buddy: buddyJane, role: DiveRole.builtInBuddy()),
            ],
          ),
          // D3: Matches only John
          Dive(
            id: 'd3',
            dateTime: DateTime.now(),
            buddy: 'John Doe',
            notes: '',
          ),
          // D4: Matches only Jane
          Dive(
            id: 'd4',
            dateTime: DateTime.now(),
            notes: '',
            buddies: [
              BuddyWithRole(buddy: buddyJane, role: DiveRole.builtInBuddy()),
            ],
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(2));
        expect(result.map((d) => d.id), containsAll(['d1', 'd2']));
      });

      group('decoOnly axis', () {
        // decoOnly is a SQL-only axis: getAllDives skips profile hydration for
        // list views and deco-stop events never reach the entity, so apply()
        // has nothing to classify from and deliberately ignores it. Consumers
        // intersect with decoFilteredDiveIdsProvider instead. Filtering here
        // would silently return nothing on every real (unhydrated) list.
        test('apply() ignores decoOnly: true', () {
          final dives = [_makeDive(id: 'd1'), _makeDive(id: 'd2')];

          expect(
            const DiveFilterState(decoOnly: true).apply(dives).map((d) => d.id),
            ['d1', 'd2'],
          );
        });

        test('apply() ignores decoOnly: false', () {
          final dives = [_makeDive(id: 'd1'), _makeDive(id: 'd2')];

          expect(
            const DiveFilterState(
              decoOnly: false,
            ).apply(dives).map((d) => d.id),
            ['d1', 'd2'],
          );
        });

        test('apply() ignores decoOnly even when a profile is hydrated', () {
          final dives = [
            _makeDive(
              id: 'deco',
              profile: const [
                DiveProfilePoint(timestamp: 0, depth: 30, decoType: 2),
              ],
            ),
            _makeDive(
              id: 'noDeco',
              profile: const [
                DiveProfilePoint(timestamp: 0, depth: 18, decoType: 0),
              ],
            ),
          ];

          expect(
            const DiveFilterState(decoOnly: true).apply(dives).map((d) => d.id),
            ['deco', 'noDeco'],
          );
        });

        test('decoOnly still combines with the axes apply() does own', () {
          final dives = [
            _makeDive(id: 'shallow', maxDepth: 12),
            _makeDive(id: 'deep', maxDepth: 40),
          ];

          expect(
            const DiveFilterState(
              decoOnly: true,
              minDepth: 30,
            ).apply(dives).map((d) => d.id),
            ['deep'],
          );
        });
      });

      group('equipmentAttr axis', () {
        EquipmentAttribute curated(String key, {String? text, double? num}) =>
            EquipmentAttribute.curated(
              equipmentId: 'eq1',
              key: key,
              valueText: text,
              valueNum: num,
            );

        test('key-only matches any dive whose gear has that curated attr', () {
          const filter = DiveFilterState(equipmentAttrKey: 'thickness_mm');
          final dives = [
            _makeDive(
              id: 'd1',
              equipment: [
                _makeEquipment('eq1', attributes: [curated('thickness_mm')]),
              ],
            ),
            _makeDive(
              id: 'd2',
              equipment: [
                _makeEquipment('eq2', attributes: [curated('size', text: 'L')]),
              ],
            ),
            _makeDive(id: 'd3'), // no equipment
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), ['d1']);
        });

        test('choice matches value_text exactly', () {
          const filter = DiveFilterState(
            equipmentAttrKey: 'size',
            equipmentAttrChoice: 'L',
          );
          final dives = [
            _makeDive(
              id: 'd1',
              equipment: [
                _makeEquipment('eq1', attributes: [curated('size', text: 'L')]),
              ],
            ),
            _makeDive(
              id: 'd2',
              equipment: [
                _makeEquipment('eq2', attributes: [curated('size', text: 'M')]),
              ],
            ),
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), ['d1']);
        });

        test('min/max bound value_num', () {
          const filter = DiveFilterState(
            equipmentAttrKey: 'thickness_mm',
            equipmentAttrMin: 4.0,
            equipmentAttrMax: 6.0,
          );
          final dives = [
            _makeDive(
              id: 'd1',
              equipment: [
                _makeEquipment(
                  'eq1',
                  attributes: [curated('thickness_mm', num: 5.0)],
                ),
              ],
            ),
            _makeDive(
              id: 'd2',
              equipment: [
                _makeEquipment(
                  'eq2',
                  attributes: [curated('thickness_mm', num: 3.0)],
                ),
              ],
            ),
            _makeDive(
              id: 'd3',
              equipment: [
                _makeEquipment(
                  'eq3',
                  attributes: [curated('thickness_mm', num: 7.0)],
                ),
              ],
            ),
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), ['d1']);
        });

        test('null value_num is excluded when a min bound is set', () {
          const filter = DiveFilterState(
            equipmentAttrKey: 'thickness_mm',
            equipmentAttrMin: 4.0,
          );
          final dives = [
            _makeDive(
              id: 'd1',
              equipment: [
                _makeEquipment(
                  'eq1',
                  // Unparseable legacy thickness: text only, no number.
                  attributes: [curated('thickness_mm', text: 'thin')],
                ),
              ],
            ),
          ];

          expect(filter.apply(dives), isEmpty);
        });

        test('thickness_mm matches only exposure suits, not hoods', () {
          const filter = DiveFilterState(equipmentAttrKey: 'thickness_mm');
          final dives = [
            _makeDive(
              id: 'suit',
              equipment: [
                _makeEquipment(
                  'eq1',
                  type: EquipmentType.wetsuit,
                  attributes: [curated('thickness_mm', num: 5.0)],
                ),
              ],
            ),
            _makeDive(
              id: 'hood',
              equipment: [
                _makeEquipment(
                  'eq2',
                  type: EquipmentType.hood,
                  attributes: [curated('thickness_mm', num: 5.0)],
                ),
              ],
            ),
          ];

          final result = filter.apply(dives);

          expect(result.map((d) => d.id), ['suit']);
        });

        test('custom attributes are ignored (curated-only, like the SQL)', () {
          const filter = DiveFilterState(equipmentAttrKey: 'my_field');
          const custom = EquipmentAttribute(
            id: 'c1',
            equipmentId: 'eq1',
            key: 'my_field',
            isCustom: true,
            valueText: 'x',
          );
          final dives = [
            _makeDive(
              id: 'd1',
              equipment: [
                _makeEquipment('eq1', attributes: [custom]),
              ],
            ),
          ];

          expect(filter.apply(dives), isEmpty);
        });
      });
    });
  });
}
