import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/download_target_providers.dart';

/// "Download now" opens the computer the diver downloaded from last (issue
/// #637), never the Apple Watch, or the picker when there is none.
void main() {
  DiveComputer computer(
    String id, {
    int? day,
    String? manufacturer,
    String? model,
  }) => DiveComputer(
    id: id,
    name: id,
    manufacturer: manufacturer,
    model: model,
    lastDownload: day == null ? null : DateTime.utc(2026, 7, day),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  test('the computer downloaded from most recently', () {
    expect(
      pickDownloadTarget([
        computer('a', day: 1),
        computer('b', day: 10),
        computer('c'),
      ])?.id,
      'b',
    );
  });

  test('never the Apple Watch', () {
    expect(
      pickDownloadTarget([
        computer('b', day: 10),
        computer('watch', day: 20, manufacturer: 'Apple', model: 'Apple Watch'),
      ])?.id,
      'b',
    );
  });

  test('none when nothing has been downloaded', () {
    expect(pickDownloadTarget([computer('c')]), isNull);
    expect(pickDownloadTarget(const []), isNull);
  });

  test('the route opens that computer\'s download, or the picker', () {
    expect(downloadRouteFor(computer('b')), '/dive-computers/b/download');
    expect(downloadRouteFor(null), '/dive-computers');
  });

  test('the provider picks from the diver\'s computers', () async {
    final container = ProviderContainer(
      overrides: [
        allDiveComputersProvider.overrideWith(
          (ref) async => [computer('a', day: 1), computer('b', day: 10)],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      (await container.read(downloadTargetComputerProvider.future))?.id,
      'b',
    );
  });
}
