import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart';
import 'package:submersion/features/universal_import/data/services/garmin_mtp_source.dart';

/// A Pigeon host API that answers from memory and records each call.
class _FakeHostApi extends Fake implements GarminMtpHostApi {
  final calls = <String>[];

  final devices = [GarminMtpDevice(id: 'dev-1', friendlyName: 'Descent G2')];
  final files = [GarminMtpFile(objectId: 'obj-1', name: 'a.fit', size: 3)];
  final bytes = Uint8List.fromList([1, 2, 3]);

  @override
  Future<List<GarminMtpDevice>> listDevices() async {
    calls.add('listDevices');
    return devices;
  }

  @override
  Future<List<GarminMtpFile>> listActivityFiles(String deviceId) async {
    calls.add('listActivityFiles $deviceId');
    return files;
  }

  @override
  Future<Uint8List> readFile(String deviceId, String objectId) async {
    calls.add('readFile $deviceId $objectId');
    return bytes;
  }
}

void main() {
  late _FakeHostApi api;
  late PigeonGarminMtpSource source;

  setUp(() {
    api = _FakeHostApi();
    source = PigeonGarminMtpSource(api);
  });

  test('listDevices answers with the host API devices', () async {
    expect(await source.listDevices(), same(api.devices));
    expect(api.calls, ['listDevices']);
  });

  test('listActivityFiles asks the host API for that device', () async {
    expect(await source.listActivityFiles('dev-1'), same(api.files));
    expect(api.calls, ['listActivityFiles dev-1']);
  });

  test('readFile asks the host API for that device and object', () async {
    expect(await source.readFile('dev-1', 'obj-1'), same(api.bytes));
    expect(api.calls, ['readFile dev-1 obj-1']);
  });

  test('without an API it builds one over the default messenger', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    expect(PigeonGarminMtpSource(), isA<GarminMtpSource>());
  });

  testWidgets(
    'watches are read over MTP on Windows',
    (tester) async => expect(GarminMtpSource.isSupportedPlatform, isTrue),
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'no other platform reads watches over MTP',
    (tester) async => expect(GarminMtpSource.isSupportedPlatform, isFalse),
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }),
  );
}
