import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/services/recent_buddy_card_links.dart';

/// The card links the app just read or wrote over NFC (issue #3728), so the
/// link Android re-dispatches for a tag still held is dropped once.
void main() {
  const link = 'https://submersion.app/b#eyJ2IjoxfQ';

  test('a link just noted is taken once, then opens again', () {
    final recent = RecentBuddyCardLinks(clock: () => DateTime(2026));
    recent.note(link);
    expect(recent.takeJustHandled(link), isTrue);
    expect(recent.takeJustHandled(link), isFalse);
  });

  test('a link noted longer ago than the window is not dropped', () {
    var now = DateTime(2026);
    final recent = RecentBuddyCardLinks(clock: () => now);
    recent.note(link);
    now = now.add(const Duration(seconds: 3));
    expect(recent.takeJustHandled(link), isFalse);
  });

  test('another link is not dropped', () {
    final recent = RecentBuddyCardLinks(clock: () => DateTime(2026));
    recent.note(link);
    expect(recent.takeJustHandled('$link-other'), isFalse);
  });
}
