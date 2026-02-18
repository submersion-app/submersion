import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/features/auto_update/data/services/update_service.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

class GithubUpdateService extends UpdateService {
  final String owner;
  final String repo;
  final String currentVersion;
  final String platformSuffix;
  final http.Client httpClient;

  GithubUpdateService({
    required this.owner,
    required this.repo,
    required this.currentVersion,
    required this.platformSuffix,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  @override
  Future<UpdateStatus> checkForUpdate() async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
      );
      final response = await httpClient.get(
        uri,
        headers: {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        return UpdateError(
          message: 'GitHub API returned ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Skip pre-releases (shouldn't happen with /releases/latest, but double-check)
      final isPreRelease = json['prerelease'] as bool? ?? false;
      if (isPreRelease) {
        return const UpToDate();
      }

      final tagName = json['tag_name'] as String;
      final remoteVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      if (!isNewer(remoteVersion, currentVersion)) {
        return const UpToDate();
      }

      // Find the matching asset for this platform
      final assets = json['assets'] as List<dynamic>;
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
      final releaseNotes = json['body'] as String?;

      return UpdateAvailable(
        version: remoteVersion,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      return UpdateError(message: e.toString());
    }
  }

  /// Compares two semver strings. Returns true if [remote] is newer than [current].
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

    for (var i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
