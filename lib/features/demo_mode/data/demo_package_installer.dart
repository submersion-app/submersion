import 'dart:io';

import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_package_extractor.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

/// Puts a sample logbook package where demo mode opens it: its database at
/// [DemoPaths.databaseFile], its photos in [DemoPaths.photosDir] or at
/// [photosUrl].
abstract class DemoPackageInstaller {
  /// Fetches [package] and leaves it ready to open.
  ///
  /// [onDownload] hears the bytes received; [onUnpack] hears the steps done
  /// after that, and is called with (0, 0) as unpacking begins. Throws
  /// [DemoDownloadException], with [DemoDownloadFailure.cancelled] once
  /// [isCancelled] says so.
  Future<void> install(
    DemoPackage package,
    DemoPaths paths, {
    bool Function()? isCancelled,
    void Function(int done, int total)? onDownload,
    void Function(int done, int total)? onUnpack,
  });

  /// Where the photos are served from when they are not files in
  /// [DemoPaths.photosDir]: a browser shows them from its site (issue
  /// #4121). Null natively.
  Uri? get photosUrl;
}

/// Throws the cancellation [DemoPackageInstaller.install] promises.
void throwIfDemoCancelled(bool Function()? isCancelled) {
  if (isCancelled?.call() ?? false) {
    throw const DemoDownloadException(DemoDownloadFailure.cancelled);
  }
}

/// The native installer: the zip downloaded and checked against the
/// manifest, then unpacked into the demo directory.
class ZipDemoPackageInstaller implements DemoPackageInstaller {
  ZipDemoPackageInstaller({required this.downloader, required this.extractor});

  final DemoDownloader downloader;
  final DemoPackageExtractor extractor;

  @override
  Uri? get photosUrl => null;

  @override
  Future<void> install(
    DemoPackage package,
    DemoPaths paths, {
    bool Function()? isCancelled,
    void Function(int done, int total)? onDownload,
    void Function(int done, int total)? onUnpack,
  }) async {
    final zip = await downloader.download(
      package,
      File(paths.packageFile),
      isCancelled: isCancelled,
      onProgress: onDownload,
    );
    // The downloader sees Cancel only as chunks land, so a tap that comes
    // with the last one is honoured here.
    throwIfDemoCancelled(isCancelled);
    onUnpack?.call(0, 0);
    await extractor.extract(zip, paths, onProgress: onUnpack);
  }
}
