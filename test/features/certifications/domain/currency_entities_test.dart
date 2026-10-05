import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

void main() {
  group('scope codec', () {
    test('decodes an agency array', () {
      expect(CurrencyScopeCodec.decodeAgencies('["padi","ssi"]'), [
        CertificationAgency.padi,
        CertificationAgency.ssi,
      ]);
    });

    test('an empty array means any, and stays empty rather than null', () {
      expect(CurrencyScopeCodec.decodeAgencies('[]'), isEmpty);
      expect(CurrencyScopeCodec.decodeLevels('[]'), isEmpty);
    });

    test('an unknown enum name is dropped, not mapped to other', () {
      // A rule written by a newer build can name a level this build lacks.
      // Mapping it to `other` would silently widen the rule's scope.
      expect(CurrencyScopeCodec.decodeLevels('["cave","levelFromTheFuture"]'), [
        CertificationLevel.cave,
      ]);
    });

    test('malformed JSON decodes to empty instead of throwing', () {
      expect(CurrencyScopeCodec.decodeStrings('not json'), isEmpty);
      expect(CurrencyScopeCodec.decodeStrings('{"not":"a list"}'), isEmpty);
    });

    test('decodes dive modes by name', () {
      expect(CurrencyScopeCodec.decodeModes('["ccr","scr"]'), [
        DiveMode.ccr,
        DiveMode.scr,
      ]);
    });

    test('an array naming nothing this build knows is unreadable', () {
      // Decoding it to [] would read as "any" and widen the rule to every
      // card; it must read as unreadable instead.
      expect(
        CurrencyScopeCodec.isReadableAgencies('["fromTheFuture"]'),
        isFalse,
      );
      expect(
        CurrencyScopeCodec.isReadableLevels('["levelFromTheFuture"]'),
        isFalse,
      );
      expect(CurrencyScopeCodec.isReadableModes('["warpDrive"]'), isFalse);
      expect(CurrencyScopeCodec.isReadableStrings('not json'), isFalse);
      expect(CurrencyScopeCodec.isReadableStrings('{"not":"a list"}'), isFalse);
    });

    test('an empty array, or one with a known name, stays readable', () {
      expect(CurrencyScopeCodec.isReadableLevels('[]'), isTrue);
      expect(
        CurrencyScopeCodec.isReadableLevels('["cave","levelFromTheFuture"]'),
        isTrue,
      );
      expect(CurrencyScopeCodec.isReadableStrings('["cave"]'), isTrue);
    });

    test('encode round trips', () {
      expect(
        CurrencyScopeCodec.encode(['cave', 'cavern']),
        '["cave","cavern"]',
      );
    });
  });

  group('entities', () {
    test('clock kind parses by name and falls back to activity', () {
      expect(CurrencyClockKind.parse('date'), CurrencyClockKind.date);
      expect(CurrencyClockKind.parse('activity'), CurrencyClockKind.activity);
      expect(CurrencyClockKind.parse('nonsense'), CurrencyClockKind.activity);
    });

    test('event type parses by name and falls back to other', () {
      expect(CurrencyEventType.parse('refresher'), CurrencyEventType.refresher);
      expect(CurrencyEventType.parse('nonsense'), CurrencyEventType.other);
    });

    test('a built-in rule reports its advisory key, a custom one its text', () {
      final builtIn = CurrencyRule(
        id: 'cave_currency',
        name: 'Cave currency',
        clockKind: CurrencyClockKind.activity,
        lapseDays: 365,
        leadDays: 90,
        advisoryKey: 'currencyRule_cave_currency_advisory',
        isBuiltIn: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(builtIn.advisoryKey, isNotNull);
      expect(builtIn.advisoryText, isNull);

      final custom = builtIn.copyWith(
        id: 'custom-1',
        isBuiltIn: false,
        advisoryText: 'My club asks for a refresher every spring',
        supersedesRuleId: 'cave_currency',
      );
      expect(custom.supersedesRuleId, 'cave_currency');
      expect(custom.isBuiltIn, isFalse);
      expect(custom.name, builtIn.name);
    });

    test('a rule encodes its scope arrays back to storage form', () {
      final rule = CurrencyRule(
        id: 'custom-1',
        name: 'Club refresher',
        clockKind: CurrencyClockKind.activity,
        agencies: const [CertificationAgency.bsac],
        levels: const [CertificationLevel.openWater],
        lapseDays: 200,
        leadDays: 30,
        countedDiveTypeIds: const ['cave'],
        countedDiveModes: const [DiveMode.ccr],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(rule.agenciesJson, '["bsac"]');
      expect(rule.levelsJson, '["openWater"]');
      expect(rule.diveTypesJson, '["cave"]');
      expect(rule.diveModesJson, '["ccr"]');
    });

    test('a pref tells inheriting apart from any-dive-counts', () {
      // NULL inherits the rule's mapping; an empty list is the diver saying
      // "any dive counts". Collapsing the two silently changes a rule.
      final inheriting = CurrencyPref(
        id: 'p1',
        certificationId: 'c1',
        ruleId: 'cave_currency',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(inheriting.countedDiveTypeIds, isNull);
      expect(inheriting.inheritsMapping, isTrue);

      final anyDive = inheriting.copyWith(countedDiveTypeIds: const []);
      expect(anyDive.countedDiveTypeIds, isEmpty);
      expect(anyDive.inheritsMapping, isFalse);
    });

    test('an event keeps its type and date', () {
      final event = CurrencyEvent(
        id: 'e1',
        certificationId: 'c1',
        ruleId: 'padi_reactivate',
        eventType: CurrencyEventType.refresher,
        eventDate: DateTime(2026, 3, 4),
        provider: 'Blue Hole Divers',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(event.eventType, CurrencyEventType.refresher);
      expect(event.eventDate, DateTime(2026, 3, 4));
      expect(event.notes, '');
    });
  });
}
