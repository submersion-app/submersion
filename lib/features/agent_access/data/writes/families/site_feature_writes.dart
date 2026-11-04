import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

/// A compass bearing held to 0 up to 360, as the feature sheet keeps one:
/// 370 is 10 and -90 is 270.
class _BearingCodec extends FieldCodec {
  const _BearingCodec() : super(nullable: true);

  @override
  String get describe => 'a bearing in degrees, kept from 0 up to 360';

  @override
  Object parseValue(Object raw) {
    if (raw is! num || !raw.isFinite) {
      throw const FieldRefusal('This field takes a number.');
    }
    final turned = raw.toDouble() % 360;
    return turned < 0 ? turned + 360 : turned;
  }

  @override
  Object? canonical(Object? documentValue) =>
      documentValue is num ? documentValue.toDouble() : documentValue;
}

/// The features a diver places on a site, through the repository the site
/// map's feature sheet uses. A feature stays where it was placed; a site a
/// shared library holds takes features only from a profile that may edit
/// it, refused here rather than skipped by the save.
class SiteFeatureWrites extends WritableEntry {
  SiteFeatureWrites(this._r, {LibraryEditStamper? stamper})
    : _stamper = stamper ?? LibraryEditStamper();

  final RecordRepositories _r;
  final LibraryEditStamper _stamper;

  @override
  String get name => 'site_features';

  @override
  String get table => 'site_features';

  @override
  ChildOf get parent => const ChildOf(entity: 'sites', field: 'site_id');

  @override
  String get note =>
      'A feature is placed at latitude and longitude when it is made and '
      'stays there; to move one, delete it and place another.';

  @override
  late final Map<String, FieldCodec> fields = {
    'site_id': const FieldCodec.reference('sites'),
    'type': FieldCodec.enumName(SiteFeatureType.values),
    'name': const FieldCodec.text(maxLength: 100, allowBlank: true, trim: true),
    'latitude': const FieldCodec.number(min: -90, max: 90),
    'longitude': const FieldCodec.number(min: -180, max: 180),
    'bearing_deg': const _BearingCodec(),
    'depth_m': const FieldCodec.number(min: 0, max: 350, nullable: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'latitude', 'longitude'};

  @override
  Set<String> get createOnly => const {'latitude', 'longitude'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['name'] as String? ?? document['type'] as String?;

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {'type': SiteFeatureType.wreck.name};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final siteId =
        check.values['site_id'] as String? ??
        check.document!['site_id']! as String;
    if (await _stamper.mayEdit(siteId, actingDiverId: check.ownerId)) {
      return null;
    }
    return const PlanBlock(
      BlockReason.notPermitted,
      'This site belongs to a shared library this profile may not edit.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.siteFeatures.addFeature(
        siteId: values['site_id']! as String,
        typeName: values['type']! as String,
        latitude: (values['latitude']! as num).toDouble(),
        longitude: (values['longitude']! as num).toDouble(),
        bearingDeg: (values['bearing_deg'] as num?)?.toDouble(),
        depthMeters: (values['depth_m'] as num?)?.toDouble(),
        name: values['name'] as String? ?? '',
        notes: values['notes'] as String? ?? '',
        actingDiverId: diverId,
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final rows = await _r.db
        .customSelect(
          'SELECT site_id FROM site_features WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    final features = rows.isEmpty
        ? const <SiteFeature>[]
        : await _r.siteFeatures.getFeaturesForSite(
            rows.single.read<String>('site_id'),
          );
    final current =
        features.where((f) => f.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Site feature $id no longer exists.',
          details: {'id': id},
        ));
    final v = update.values;
    double? kept(String key, double? held) =>
        v.containsKey(key) ? (v[key] as num?)?.toDouble() : held;
    await _r.siteFeatures.updateFeature(
      SiteFeature(
        id: id,
        siteId: current.siteId,
        typeName: v['type'] as String? ?? current.typeName,
        name: v['name'] as String? ?? current.name,
        latitude: current.latitude,
        longitude: current.longitude,
        bearingDeg: kept('bearing_deg', current.bearingDeg),
        depthMeters: kept('depth_m', current.depthMeters),
        notes: v['notes'] as String? ?? current.notes,
      ),
      actingDiverId: ownerId,
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.siteFeatures.deleteFeature(id, actingDiverId: ownerId);
}
