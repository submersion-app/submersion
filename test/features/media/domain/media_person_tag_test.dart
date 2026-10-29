import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

/// Domain entities carry copyWith (CLAUDE.md, Code Conventions).
void main() {
  const box = FaceBox(x: 0.1, y: 0.2, width: 0.3, height: 0.4);

  test('FaceBox.copyWith changes only the given sides', () {
    expect(
      box.copyWith(x: 0.5),
      const FaceBox(x: 0.5, y: 0.2, width: 0.3, height: 0.4),
    );
    expect(box.copyWith(), box);
  });

  test('MediaPersonChip.copyWith keeps what it is not given', () {
    final tag = MediaPersonTag(
      id: 't',
      mediaId: 'm',
      buddyId: 'b',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    final chip = MediaPersonChip(tag: tag, buddyName: 'Alex');
    expect(chip.copyWith(buddyName: 'Al').buddyName, 'Al');
    expect(chip.copyWith(buddyName: 'Al').tag, tag);
    expect(chip.copyWith(), chip);
  });
}
