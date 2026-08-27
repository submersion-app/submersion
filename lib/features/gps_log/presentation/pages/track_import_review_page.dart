import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_timezone_resolver.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/csv_column_mapping_form.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Confirms a parsed track before writing it.
///
/// The timezone selector is the reason this screen exists: the file's times
/// are real UTC, the app stores wall-clock-as-UTC, and a wrong offset yields
/// a track that looks fine but silently matches zero dives. Showing the
/// resulting first-fix time live makes a bad guess visible before the write
/// rather than after.
class TrackImportReviewPage extends ConsumerStatefulWidget {
  const TrackImportReviewPage({
    super.key,
    required this.candidate,
    required this.bytes,
  });

  final TrackImportCandidate candidate;

  /// Kept so a CSV mapping change can re-parse without re-reading the file.
  final Uint8List bytes;

  @override
  ConsumerState<TrackImportReviewPage> createState() =>
      _TrackImportReviewPageState();
}

class _TrackImportReviewPageState extends ConsumerState<TrackImportReviewPage> {
  late TrackImportCandidate _candidate = widget.candidate;
  late int _offsetMinutes = widget.candidate.tzOffsetMinutes;
  CsvColumnMapping? _mapping;
  String? _error;
  bool _busy = false;

  /// Real UTC offsets in quarter-hour steps from -12:00 to +14:00.
  static final List<int> _offsets = [for (var m = -720; m <= 840; m += 15) m];

  String _formatOffset(int minutes) {
    final sign = minutes < 0 ? '-' : '+';
    final abs = minutes.abs();
    final h = (abs ~/ 60).toString().padLeft(2, '0');
    final m = (abs % 60).toString().padLeft(2, '0');
    return 'UTC$sign$h:$m';
  }

  /// First fix rendered in the currently selected zone.
  String get _firstFixPreview {
    final fix = _candidate.parsed.fixes.first;
    final wall = DateTime.fromMillisecondsSinceEpoch(
      toWallClockEpochSecondsAt(fix.utc, _offsetMinutes) * 1000,
      isUtc: true,
    );
    final units = UnitFormatter(ref.read(settingsProvider));
    return '${units.formatDate(wall)} ${units.formatTime(wall)}';
  }

  void _remapCsv(CsvColumnMapping mapping) {
    try {
      final reparsed = parseCsv(widget.bytes, mapping);
      setState(() {
        _mapping = mapping;
        _candidate = _candidate.copyWith(parsed: reparsed);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _import() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref
          .read(trackImportServiceProvider)
          .commit(_candidate.copyWith(tzOffsetMinutes: _offsetMinutes));
      if (!mounted) return;
      navigator.pop(true);
    } on TrackParseException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(trackParseErrorText(l10n, e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsTrack_import_failed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final fixes = _candidate.parsed.fixes;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gpsTrack_import_reviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _candidate.parsed.name ?? _candidate.sourceRef,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gpsTrack_import_fixCount(fixes.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_candidate.duplicateOfTrackId != null) ...[
            const SizedBox(height: 12),
            Card(
              key: const ValueKey('import-duplicate-warning'),
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.copy_all_outlined,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.gpsTrack_import_duplicate,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.gpsTrack_import_timezone,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.gpsTrack_import_timezoneHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: const ValueKey('import-tz-offset'),
            initialValue: _offsetMinutes,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final m in _offsets)
                DropdownMenuItem(value: m, child: Text(_formatOffset(m))),
            ],
            onChanged: (v) =>
                v == null ? null : setState(() => _offsetMinutes = v),
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.gpsTrack_import_firstFix}: $_firstFixPreview',
            key: const ValueKey('import-first-fix-preview'),
            style: theme.textTheme.bodyMedium,
          ),
          if (_candidate.format == TrackFileFormat.csv) ...[
            const SizedBox(height: 24),
            CsvColumnMappingForm(
              headers: readCsvHeaders(widget.bytes),
              mapping:
                  _mapping ?? guessCsvMapping(readCsvHeaders(widget.bytes))!,
              onChanged: _remapCsv,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('import-confirm'),
            onPressed: _busy ? null : _import,
            child: Text(l10n.gpsTrack_import_confirm),
          ),
        ],
      ),
    );
  }
}
