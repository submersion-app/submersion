import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Maps each top-level entitlement key to the element name of its value
/// (`true`, `false`, `array`, `string`, ...).
///
/// Parsed structurally rather than matched as text: asserting only that a
/// `<key>` is present would pass for a key explicitly set to `<false/>`, which
/// is exactly how a build turns a capability OFF (see
/// `ReleaseNoSandbox.entitlements`, which disables the sandbox that way). These
/// files also carry XML comments between entries, which a whitespace-based
/// pattern would trip over but `childElements` skips.
Map<String, String> entitlementValueTypes(String plistXml) {
  final dict = XmlDocument.parse(plistXml).rootElement.getElement('dict');
  if (dict == null) return const {};

  final types = <String, String>{};
  final children = dict.childElements.toList();
  for (var i = 0; i + 1 < children.length; i++) {
    if (children[i].name.local != 'key') continue;
    final value = children[i + 1];
    // A key immediately followed by another key is malformed; skip rather than
    // record a bogus value type.
    if (value.name.local == 'key') continue;
    types[children[i].innerText.trim()] = value.name.local;
  }
  return types;
}

/// Guards the macOS entitlements the app needs at runtime.
///
/// These are file assertions rather than platform tests so they run on the
/// Linux CI/coverage host: an entitlement is only enforced by the OS on a
/// signed, sandboxed macOS build talking to real hardware, which CI never does.
/// A missing or disabled key is invisible until a user plugs in a cable, so the
/// file itself is the only regression surface CI can see.
void main() {
  /// The sandboxed macOS builds. `ReleaseNoSandbox.entitlements` is handled
  /// separately: it disables the sandbox, so sandbox hardware entitlements are
  /// inert there.
  const sandboxedEntitlements = <String>[
    'macos/Runner/DebugProfile.entitlements',
    'macos/Runner/Release.entitlements',
  ];
  const noSandboxEntitlements = 'macos/Runner/ReleaseNoSandbox.entitlements';

  Map<String, String> typesOf(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path is missing');
    return entitlementValueTypes(file.readAsStringSync());
  }

  group('entitlementValueTypes', () {
    // These fixtures prove the assertions below actually assert something: a
    // key set to <false/> must NOT read as enabled.
    const plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
	<key>enabled.capability</key>
	<true/>
	<!-- a comment between entries, as the real files have -->
	<key>disabled.capability</key>
	<false/>
	<key>list.capability</key>
	<array>
		<string>one</string>
	</array>
</dict>
</plist>
''';

    test('distinguishes an enabled key from one explicitly set to false', () {
      final types = entitlementValueTypes(plist);
      expect(types['enabled.capability'], 'true');
      expect(types['disabled.capability'], 'false');
    });

    test('reads past interleaved comments and non-boolean values', () {
      final types = entitlementValueTypes(plist);
      expect(types['list.capability'], 'array');
      expect(types.keys, hasLength(3));
    });

    test('reports absent keys as null', () {
      expect(entitlementValueTypes(plist)['never.declared'], isNull);
    });
  });

  group('macOS sandboxed entitlements', () {
    for (final path in sandboxedEntitlements) {
      test('$path enables the serial-port entitlement (issue #291)', () {
        // Without com.apple.security.device.serial set to true, a sandboxed app
        // is denied open(2) on /dev/cu.* with EPERM, so every USB-serial dive
        // computer download fails with "Failed to open serial port". IOKit
        // enumeration is NOT gated the same way, so the port is still
        // discovered and the failure looks like a driver or cable problem
        // rather than a permission one.
        expect(
          typesOf(path)['com.apple.security.device.serial'],
          'true',
          reason:
              'Sandboxed macOS builds cannot open /dev/cu.* serial devices '
              'without com.apple.security.device.serial. Removing it, or '
              'setting it to false, silently breaks all USB-cable dive '
              'computer downloads (issue #291).',
        );
      });

      test('$path enables the USB device entitlement (issue #732)', () {
        // Some dive-computer cables are FTDI chips carrying a custom USB
        // product ID that macOS does not claim, so no /dev/cu.* node is ever
        // created and the serial entitlement above cannot help. Those cables
        // are driven over raw USB instead, which the sandbox gates on this
        // key: application.sb grants IOUSBDeviceUserClientV2 and
        // IOUSBInterfaceUserClientV3 only when it is present.
        expect(
          typesOf(path)['com.apple.security.device.usb'],
          'true',
          reason:
              'Sandboxed macOS builds cannot open a USB device directly '
              'without com.apple.security.device.usb. Removing it, or setting '
              'it to false, silently breaks downloads from dive computers '
              'whose cable macOS does not expose as a serial port (issue '
              '#732).',
        );
      });

      test('$path keeps the sandbox enabled', () {
        // Anchor for the assertion above: if a build ever turns the sandbox
        // off, the serial entitlement stops meaning what it claims to mean.
        expect(
          typesOf(path)['com.apple.security.app-sandbox'],
          'true',
          reason: '$path is expected to be a sandboxed build',
        );
      });
    }

    test('$noSandboxEntitlements is genuinely unsandboxed', () {
      // Documents why the file is excluded above: with the sandbox off, serial
      // access needs no entitlement. If this ever became a sandboxed build it
      // would need com.apple.security.device.serial too.
      expect(
        typesOf(noSandboxEntitlements)['com.apple.security.app-sandbox'],
        'false',
        reason:
            'ReleaseNoSandbox is excluded from the serial-entitlement check '
            'only because it disables the sandbox',
      );
    });
  });
}
