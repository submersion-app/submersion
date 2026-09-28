import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/presentation/services/recent_passport_tags.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const read = 'https://submersion.app/c#f=1&p=$id&w=2026-09-25';
  var now = DateTime(2026, 9, 27, 10);
  late RecentPassportTags recent;

  setUp(() {
    now = DateTime(2026, 9, 27, 10);
    recent = RecentPassportTags(clock: () => now);
  });

  test('a tag just handled in the app is recognised by its passport', () {
    recent.note(read);
    // The same cylinder's tag in another form (the custom scheme, newer w).
    expect(
      recent.wasJustHandled('submersion://c?f=1&p=$id&w=2026-09-27'),
      isTrue,
    );
  });

  test('the memory lasts only a few seconds', () {
    recent.note(read);
    now = now.add(const Duration(seconds: 6));
    expect(recent.wasJustHandled(read), isFalse);
  });

  test('another cylinder or text that is no tag is not recognised', () {
    recent.note(read);
    expect(
      recent.wasJustHandled(
        'https://submersion.app/c#f=1&p=11111111-2222-4333-8444-555555555555',
      ),
      isFalse,
    );
    expect(recent.wasJustHandled('hello'), isFalse);
    recent.note('hello');
    expect(recent.wasJustHandled(read), isTrue);
  });
}
