import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_suggestion.dart';
import 'package:submersion/features/equipment/domain/services/equipment_suggestion_url.dart';

const _spg = EquipmentSuggestion(
  kind: EquipmentSuggestionKind.subcategory,
  name: 'Submersible pressure gauge',
  parent: EquipmentType.instrument,
  reason: 'Serviced on its own schedule.',
  example: 'Scubapro 52 mm brass',
);

Uri _build(EquipmentSuggestion suggestion) => buildEquipmentSuggestionUrl(
  suggestion: suggestion,
  locale: 'sv',
  appVersion: '1.8.7.8001',
);

void main() {
  test('targets the equipment issue form with every field filled', () {
    final uri = _build(_spg);

    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/submersion-app/submersion/issues/new');
    expect(uri.queryParameters, {
      'template': 'equipment-suggestion.yml',
      'title': 'Equipment suggestion: Submersible pressure gauge',
      'kind': 'Subcategory',
      'name': 'Submersible pressure gauge',
      'parent': 'Instrument / Gauge (instrument)',
      'reason': 'Serviced on its own schedule.',
      'example': 'Scubapro 52 mm brass',
      'locale': 'sv',
      'app_version': '1.8.7.8001',
    });
  });

  test('a category with no parent sends None, and no example key', () {
    final uri = _build(
      const EquipmentSuggestion(
        kind: EquipmentSuggestionKind.category,
        name: 'Scooter tow leash',
        reason: 'Not a DPV and not a reel.',
      ),
    );

    expect(uri.queryParameters['kind'], 'Category');
    expect(uri.queryParameters['parent'], 'None');
    expect(uri.queryParameters.containsKey('example'), isFalse);
  });

  test('a blank example sends no example key', () {
    final uri = _build(_spg.copyWith(example: '   '));

    expect(uri.queryParameters.containsKey('example'), isFalse);
  });

  test('never asks for labels through the URL', () {
    expect(_build(_spg).queryParameters.containsKey('labels'), isFalse);
  });

  test('free text with reserved characters and other scripts round-trips', () {
    const reason = 'Fits A & B? #2790\nSecond line, 日本語, עברית, 🐠';
    const name = 'Gauge & hose #1?';
    final uri = _build(_spg.copyWith(name: name, reason: reason));

    final parsed = Uri.parse(uri.toString());
    expect(parsed.queryParameters['reason'], reason);
    expect(parsed.queryParameters['name'], name);
    expect(parsed.queryParameters['title'], 'Equipment suggestion: $name');
  });

  test('keeps the URL under 8000 by trimming the reason first', () {
    final uri = _build(_spg.copyWith(reason: 'x' * 20000));

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(uri.queryParameters['name'], _spg.name);
    expect(uri.queryParameters['example'], _spg.example);
    expect(uri.queryParameters['reason']!.length, lessThan(20000));
  });

  test('trims the example after the reason', () {
    final uri = _build(
      _spg.copyWith(reason: 'x' * 20000, example: 'e' * 20000),
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(uri.queryParameters['name'], _spg.name);
    expect(uri.queryParameters['reason'] ?? '', isEmpty);
  });

  test('trims the name last and keeps at least one character', () {
    final uri = _build(
      _spg.copyWith(
        name: 'n' * 20000,
        reason: 'x' * 20000,
        example: 'e' * 20000,
      ),
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(uri.queryParameters['name'], isNotEmpty);
  });

  test('every field the builder sends is an id in the issue form', () {
    final form = File(
      p.join('.github', 'ISSUE_TEMPLATE', 'equipment-suggestion.yml'),
    ).readAsStringSync();
    final ids = RegExp(
      r'^\s+id:\s*(\S+)',
      multiLine: true,
    ).allMatches(form).map((m) => m.group(1)).toSet();

    final sent = _build(_spg).queryParameters.keys.toSet()
      ..removeAll(['template', 'title']);
    expect(ids, containsAll(sent));
    expect(form, contains('labels: ["equipment-suggestion", "enhancement"]'));
  });
}
