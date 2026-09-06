import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

class GithubUpdateService extends UpdateService {
  final String owner;
  final String repo;
  final String currentVersion;
  final String platformSuffix;

  /// Whether pre-releases count as updates.
  ///
  /// The stable channel reads `/releases/latest`, which is exactly the release
  /// GitHub badges "Latest". Every beta in `beta-builds` is published with
  /// `--prerelease` (#1591) so that badge never lands on an installer, which
  /// puts the whole repo out of reach of that endpoint: it excludes
  /// pre-releases and 404s when nothing else remains. The beta channel
  /// therefore enumerates releases and picks the highest version itself.
  final bool includePrereleases;

  final http.Client httpClient;

  GithubUpdateService({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    required this.platformSuffix,
    this.includePrereleases = false,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// The API maximum, not the 30 the prune step aims to keep: a prune that
  /// fails or is delayed would otherwise push the newest beta off page one.
  Uri get _endpoint => Uri.parse(
    includePrereleases
        ? 'https://api.github.com/repos/$owner/$repo/releases?per_page=100'
        : 'https://api.github.com/repos/$owner/$repo/releases/latest',
  );

  @override
  Future<UpdateStatus> checkForUpdate() async {
    try {
      final response = await httpClient.get(
        _endpoint,
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return UpdateError(
          message: 'GitHub API returned ${response.statusCode}',
        );
      }

      final release = _selectRelease(jsonDecode(response.body));
      if (release == null) return const UpToDate();

      final remoteVersion = _versionOf(release);
      if (!isNewer(remoteVersion, currentVersion)) {
        return const UpToDate();
      }

      // Find the matching asset for this platform
      final assets = release['assets'] as List<dynamic>;
      final matchingAsset = assets.cast<Map<String, dynamic>>().where((asset) {
        final name = asset['name'] as String;
        return name.endsWith(platformSuffix);
      });

      if (matchingAsset.isEmpty) {
        return const UpdateError(
          message: 'No matching download found for this platform',
        );
      }

      final downloadUrl = matchingAsset.first['browser_download_url'] as String;
      final releaseNotes = release['body'] as String?;

      return UpdateAvailable(
        version: remoteVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      return UpdateError(message: e.toString());
    }
  }

  /// The release this check should consider, or null when there is none.
  Map<String, dynamic>? _selectRelease(dynamic decoded) {
    if (!includePrereleases) {
      final release = decoded as Map<String, dynamic>;
      // Skip pre-releases (shouldn't happen with /releases/latest, but double-check)
      if (release['prerelease'] as bool? ?? false) return null;
      return release;
    }

    // GitHub returns the list newest-first by tag creation date, but every
    // beta-builds release shares one creation date, so that order says
    // nothing about which build is newest. Compare versions instead. The
    // permanent "appcast" pointer release, which exists only to keep the
    // Sparkle feed URL resolving, parses as version 0 and so never wins.
    Map<String, dynamic>? newest;
    for (final release
        in (decoded as List<dynamic>).cast<Map<String, dynamic>>()) {
      if (release['draft'] as bool? ?? false) continue;
      if (newest == null || isNewer(_versionOf(release), _versionOf(newest))) {
        newest = release;
      }
    }
    return newest;
  }

  static String _versionOf(Map<String, dynamic> release) {
    final tagName = release['tag_name'] as String;
    return tagName.startsWith('v') ? tagName.substring(1) : tagName;
  }

  /// Compares two version strings. Returns true if [remote] is newer than [current].
  /// Supports any number of dot-separated segments (e.g., "1.2.21.65").
  /// Pre-release suffixes (e.g., "-beta.1") are stripped before comparison.
  static bool isNewer(String remote, String current) {
    // Strip pre-release suffix (e.g., "2.0.0-beta.1" -> "2.0.0")
    final remoteBase = remote.split('-').first;
    final currentBase = current.split('-').first;

    final remoteParts = remoteBase
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    final currentParts = currentBase
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    final maxLen = remoteParts.length > currentParts.length
        ? remoteParts.length
        : currentParts.length;
    for (var i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
