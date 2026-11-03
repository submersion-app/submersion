import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/database/background_database_connection.dart';
import 'package:submersion/core/platform/compute/compute_jobs.dart';
import 'package:submersion/features/demo_mode/data/demo_downloader.dart';
import 'package:submersion/features/demo_mode/data/demo_manifest_client.dart';
import 'package:submersion/features/demo_mode/data/demo_package_installer.dart';
import 'package:submersion/features/demo_mode/data/demo_paths.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';

/// A browser's sample logbook ships inside the site (issue #4121): a page
/// cannot read the GitHub release the app downloads it from, so the web
/// build unpacks the package into `demo/` beside the page, with the
/// database gzipped and an index naming it (`fetch_demo_db.py
/// --web-index`).

/// The index of the sample logbook, relative to the page.
const String kBundledDemoIndex = 'demo/demo.json';

/// Reads the index the site ships, in place of the release manifest.
///
/// The package it offers is the gzipped database: [DemoPackage.size] is
/// what a visitor downloads, and [DemoPackage.sha256] is the hash of the
/// database once inflated, which [BundledDemoPackageInstaller] checks.
class BundledDemoManifestClient implements DemoManifestClient {
  BundledDemoManifestClient({
    http.Client? client,
    Uri? index,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _index = index ?? Uri.base.resolve(kBundledDemoIndex);

  final http.Client _client;
  final Uri _index;

  @override
  final Duration timeout;

  /// The site's sample logbook, or null when it ships none (a host who
  /// deleted the folder, or a build without it), an app older than the
  /// logbook is asking, or anything goes wrong: the entry points hide.
  @override
  Future<DemoPackage?> fetchBest(int appSchemaVersion) async {
    try {
      final response = await _client.get(_index).timeout(timeout);
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map || json['formatVersion'] != 1) return null;
      final schema = json['schemaVersion'] as int;
      if (schema > appSchemaVersion) return null;
      final database = json['database'] as Map;
      return DemoPackage(
        schemaVersion: schema,
        url: _index.resolve(database['path'] as String),
        sha256: database['sha256'] as String,
        size: database['compressedSize'] as int,
        generatedAt: DateTime.parse(json['generatedAt'] as String),
      );
    } on TimeoutException {
      return null;
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }
}

/// Fetches the site's gzipped sample logbook, inflates and checks it, and
/// installs it as the browser database demo mode opens. The photos stay on
/// the site at [photosUrl].
class BundledDemoPackageInstaller implements DemoPackageInstaller {
  BundledDemoPackageInstaller({
    http.Client? client,
    required this.photosUrl,
    Future<Uint8List> Function(Uint8List packed)? inflate,
    Future<void> Function(String path, Uint8List image)? installImage,
  }) : _client = client ?? http.Client(),
       _inflate = inflate ?? ComputeJobs.gunzip,
       _installImage =
           installImage ?? BackgroundDatabaseConnection.installImage;

  final http.Client _client;
  final Future<Uint8List> Function(Uint8List packed) _inflate;
  final Future<void> Function(String path, Uint8List image) _installImage;

  @override
  final Uri? photosUrl;

  @override
  Future<void> install(
    DemoPackage package,
    DemoPaths paths, {
    bool Function()? isCancelled,
    void Function(int done, int total)? onDownload,
    void Function(int done, int total)? onUnpack,
  }) async {
    final packed = await _download(package, isCancelled, onDownload);
    throwIfDemoCancelled(isCancelled);
    onUnpack?.call(0, 0);
    final Uint8List image;
    try {
      image = await _inflate(packed);
    } on Exception catch (e) {
      throw DemoDownloadException(DemoDownloadFailure.checksumMismatch, '$e');
    }
    onUnpack?.call(1, 3);
    final digest = _hex(await ComputeJobs.sha256(image));
    if (digest != package.sha256.toLowerCase()) {
      throw DemoDownloadException(DemoDownloadFailure.checksumMismatch, digest);
    }
    onUnpack?.call(2, 3);
    throwIfDemoCancelled(isCancelled);
    await _installImage(paths.databaseFile, image);
    onUnpack?.call(3, 3);
  }

  Future<Uint8List> _download(
    DemoPackage package,
    bool Function()? isCancelled,
    void Function(int done, int total)? onDownload,
  ) async {
    final http.StreamedResponse response;
    try {
      response = await _client.send(http.Request('GET', package.url));
    } on http.ClientException catch (e) {
      throw DemoDownloadException(DemoDownloadFailure.network, e.message);
    }
    if (response.statusCode != 200) {
      throw DemoDownloadException(
        DemoDownloadFailure.httpStatus,
        '${response.statusCode}',
      );
    }
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.stream) {
        throwIfDemoCancelled(isCancelled);
        bytes.add(chunk);
        if (bytes.length > package.size) {
          throw const DemoDownloadException(DemoDownloadFailure.sizeMismatch);
        }
        onDownload?.call(bytes.length, package.size);
      }
    } on http.ClientException catch (e) {
      throw DemoDownloadException(DemoDownloadFailure.network, e.message);
    }
    if (bytes.length != package.size) {
      throw const DemoDownloadException(DemoDownloadFailure.sizeMismatch);
    }
    return bytes.takeBytes();
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
