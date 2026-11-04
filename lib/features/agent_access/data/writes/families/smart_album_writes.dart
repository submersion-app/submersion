import 'package:submersion/features/agent_access/data/documents/document_dates.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/json_object_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// [raw], an album filter as a read shows it (date bounds as days), as the
/// filter it keeps, or a refusal for one that narrows nothing.
MediaLibraryFilter _filterOf(Map<String, Object?> raw) {
  int? millis(String key) {
    final day = calendarDay(raw[key]);
    return day == null
        ? null
        : DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch;
  }

  final filter = MediaLibraryFilter.fromJson({
    for (final MapEntry(:key, :value) in raw.entries)
      if (key != 'from_date' && key != 'to_date') key: value,
    'fromDate': millis('from_date'),
    'toDate': millis('to_date'),
  });
  if (filter.isEmpty) {
    throw const FieldRefusal(
      'A smart album filter narrows at least one thing.',
    );
  }
  return filter;
}

/// The filter as the read shows it, from [filter].
Map<String, Object?> _shown(MediaLibraryFilter filter) => {
  for (final MapEntry(:key, :value) in filter.toJson().entries)
    if (key != 'fromDate' && key != 'toDate') key: value,
  'from_date': calendarDate(filter.fromDate),
  'to_date': calendarDate(filter.toDate),
};

/// Smart albums, through the repository the media library saves them
/// with. An album keeps the filter it was made with; it is renamed or
/// deleted, as the library offers.
class SmartAlbumWrites extends WritableEntry {
  SmartAlbumWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'smart_albums';

  @override
  String get table => 'media_smart_albums';

  @override
  String get note =>
      'filter is set when an album is made, as a read shows one: a value '
      'this version does not know is left out. from_date and to_date are '
      'days.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'filter': JsonObjectCodec(
      shape: 'a media filter object',
      normalize: (raw) => _shown(_filterOf(raw)),
    ),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'filter'};

  @override
  Set<String> get createOnly => const {'filter'};

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.smartAlbums.create(
        name: values['name']! as String,
        filter: _filterOf(JsonObjectCodec.decoded(values['filter'])),
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (update.values['name'] case final String name) {
      await _r.smartAlbums.rename(id, name);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.smartAlbums.delete(id);
}
