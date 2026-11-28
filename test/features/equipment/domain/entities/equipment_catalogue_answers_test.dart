import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_catalogue_answers.dart';

void main() {
  test('no answers encode as nothing', () {
    expect(EquipmentCatalogueAnswers.empty.encode(), isNull);
    expect(EquipmentCatalogueAnswers.empty.isEmpty, isTrue);
  });

  test('answers round-trip', () {
    final answers = EquipmentCatalogueAnswers.empty
        .withNotSame('mares-quad')
        .withDeclined('shearwater-perdix-2', ['mount'])
        .withDeclined('shearwater-perdix-2', ['connectivity']);
    final read = EquipmentCatalogueAnswers.decode(answers.encode());
    expect(read, answers);
    expect(read.declined['shearwater-perdix-2'], {'mount', 'connectivity'});
    expect(read.notSame, {'mares-quad'});
  });

  test('encoding is sorted, so equal answers are written alike', () {
    final a = EquipmentCatalogueAnswers.empty
        .withDeclined('b', ['y', 'x'])
        .withDeclined('a', ['z']);
    final b = EquipmentCatalogueAnswers.empty
        .withDeclined('a', ['z'])
        .withDeclined('b', ['x', 'y']);
    expect(a.encode(), b.encode());
  });

  test('a round trip keeps keys from a newer build', () {
    const stored = '{"declined":{"r":["mount"]},"later":{"x":1}}';
    final read = EquipmentCatalogueAnswers.decode(stored);
    expect(read.unknown, {
      'later': {'x': 1},
    });
    final rewritten = EquipmentCatalogueAnswers.decode(
      read.withNotSame('q').encode(),
    );
    expect(rewritten.unknown, read.unknown);
    expect(rewritten.notSame, {'q'});
  });

  test('decode of garbage is no answers', () {
    expect(EquipmentCatalogueAnswers.decode(null).isEmpty, isTrue);
    expect(EquipmentCatalogueAnswers.decode('{nope').isEmpty, isTrue);
    expect(EquipmentCatalogueAnswers.decode('[1,2]').isEmpty, isTrue);
    expect(
      EquipmentCatalogueAnswers.decode('{"not":"x","declined":5}').isEmpty,
      isTrue,
    );
  });

  test('copyWith replaces only what it is given', () {
    final answers = EquipmentCatalogueAnswers.empty.withNotSame('a');
    final changed = answers.copyWith(
      declined: {
        'r': {'mount'},
      },
    );
    expect(changed.notSame, {'a'});
    expect(changed.declined, {
      'r': {'mount'},
    });
    expect(answers.copyWith(), answers);
  });
}
