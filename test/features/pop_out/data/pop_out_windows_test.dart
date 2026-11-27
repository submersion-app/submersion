import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows_web.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

import '../../../helpers/fake_pop_out_windows.dart';

void main() {
  test('web stub reports nothing open and no launch', () async {
    final windows = createPopOutWindows();
    expect(await windows.isOpen(), isFalse);
    expect(await windows.currentLaunch(), isNull);
    // Sending with no pop-out is a no-op, never an error.
    await windows.channelNamed('x').send(const LockMessage(true));
  });

  test('fake channel delivers to the handler', () {
    final channel = FakePopOutChannel();
    final received = <PopOutMessage>[];
    channel.setHandler(received.add);
    channel.deliver(const ShowDiveMessage('a'));
    channel.setHandler(null);
    channel.deliver(const ShowDiveMessage('b'));
    expect(received, [const ShowDiveMessage('a')]);
  });
}
