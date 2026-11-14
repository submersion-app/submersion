import 'dart:convert';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/constants/enums.dart';

/// Diver profiles, through the repository the profile hub's edit pages use:
/// a save reads the profile, changes it and writes it back whole. A profile
/// becomes the default through the app's own switch, which clears the
/// others. Profiles are deleted only in the app, which offers to move their
/// dives first.
class DiverWrites extends WritableEntry {
  DiverWrites(this._r);

  final RecordRepositories _r;

  static const _contactKeys = {'name', 'phone', 'relation'};

  @override
  String get name => 'divers';

  @override
  String get table => 'divers';

  @override
  String get ownerColumn => 'id';

  @override
  String get note =>
      'is_default takes true only: it makes this the default profile in '
      'place of the current one. prior_dive_time_s is whole minutes, in '
      'seconds. diving_since_date holds a year, written YYYY-01-01. A profile '
      'cannot be deleted here.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'email': const FieldCodec.text(maxLength: 200, nullable: true, trim: true),
    'phone': const FieldCodec.text(maxLength: 50, nullable: true, trim: true),
    'social_handle': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'emergency_contact': const FieldCodec.textObject(keys: _contactKeys),
    'emergency_contact_2': const FieldCodec.textObject(keys: _contactKeys),
    'medical_notes': const FieldCodec.text(allowBlank: true, trim: true),
    'blood_type': const FieldCodec.text(
      maxLength: 20,
      nullable: true,
      trim: true,
    ),
    'allergies': const FieldCodec.text(nullable: true, trim: true),
    'medications': const FieldCodec.text(nullable: true, trim: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'is_default': const FieldCodec.flag(),
    'prior_dive_count': const FieldCodec.integer(
      min: 0,
      max: 100000,
      nullable: true,
    ),
    'prior_dive_time_s': const FieldCodec.integer(
      min: 0,
      max: 360000000,
      nullable: true,
    ),
    'diving_since_date': const FieldCodec.calendarDate(nullable: true),
    // Used only to estimate body fat for the weight prediction (issue
    // #4525).
    'sex': FieldCodec.enumName(DiverSex.values, nullable: true),
    'birth_year': const FieldCodec.integer(
      min: 1900,
      max: 2200,
      nullable: true,
    ),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => const {'diver_settings': 1};

  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async => values['is_default'] == true ? await _defaults(null) : const {};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A diver profile is deleted in the app, which offers to move its '
        'dives to another profile first.',
      );
    }
    final v = check.values;
    if (v['email'] case final String email
        when !email.contains('@') || !email.contains('.')) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'email: an address with an @ and a dot.',
      );
    }
    if (v['is_default'] == false) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'is_default: make another profile the default instead.',
      );
    }
    if (v['prior_dive_time_s'] case final int seconds when seconds % 60 != 0) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'prior_dive_time_s: whole minutes, as hours and minutes are kept.',
      );
    }
    final since = calendarDay(v['diving_since_date']);
    if (since != null &&
        (since.month != 1 ||
            since.day != 1 ||
            since.year < 1900 ||
            since.year > DateTime.now().year)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'diving_since_date: a year from 1900 to ${DateTime.now().year}, '
        'written YYYY-01-01.',
      );
    }
    final born = v['birth_year'];
    if (born is int && born > DateTime.now().year) {
      return PlanBlock(
        BlockReason.invalidValue,
        'birth_year: a year from 1900 to ${DateTime.now().year}.',
      );
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => update.values['is_default'] == true
      ? SideEffects(touched: await _defaults(id))
      : const SideEffects();

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final diver = await _r.divers.createDiver(
      _applied(
        Diver(
          id: '',
          name: values['name']! as String,
          createdAt: now,
          updatedAt: now,
        ),
        values,
      ),
    );
    if (values['is_default'] == true) {
      await _r.divers.setDefaultDiver(diver.id);
    }
    return diver.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    if (v.keys.any((k) => k != 'is_default')) {
      final current =
          await _r.divers.getDiverById(id) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Diver $id no longer exists.',
            details: {'id': id},
          ));
      await _r.divers.updateDiver(_applied(current, v));
    }
    if (v['is_default'] == true) await _r.divers.setDefaultDiver(id);
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      throw UnsupportedError('A diver profile is deleted in the app.');

  /// The other profiles that are the default now, which a new default
  /// clears.
  Future<Map<String, int>> _defaults(String? id) async {
    final others = [
      for (final d in await _r.divers.getAllDivers())
        if (d.isDefault && d.id != id) d.id,
    ];
    return {if (others.isNotEmpty) 'divers': others.length};
  }

  /// [diver] with [values] written over it, `is_default` aside: the
  /// default moves through its own switch.
  static Diver _applied(Diver diver, Map<String, Object?> values) {
    Object? kept(String key, Object? held) =>
        values.containsKey(key) ? values[key] : held;
    EmergencyContact contact(String key, EmergencyContact held) {
      if (!values.containsKey(key)) return held;
      // The parsed contact is its JSON, as the codec compares it.
      final parsed = jsonDecode(values[key]! as String) as Map<String, Object?>;
      return EmergencyContact(
        name: parsed['name'] as String?,
        phone: parsed['phone'] as String?,
        relation: parsed['relation'] as String?,
      );
    }

    return diver.copyWith(
      name: values['name'] as String?,
      email: kept('email', diver.email),
      phone: kept('phone', diver.phone),
      socialHandle: kept('social_handle', diver.socialHandle),
      emergencyContact: contact('emergency_contact', diver.emergencyContact),
      emergencyContact2: contact(
        'emergency_contact_2',
        diver.emergencyContact2,
      ),
      medicalNotes: values['medical_notes'] as String?,
      bloodType: kept('blood_type', diver.bloodType),
      allergies: kept('allergies', diver.allergies),
      medications: kept('medications', diver.medications),
      notes: values['notes'] as String?,
      priorDiveCount: kept('prior_dive_count', diver.priorDiveCount),
      priorDiveTimeSeconds: kept(
        'prior_dive_time_s',
        diver.priorDiveTimeSeconds,
      ),
      divingSince: values.containsKey('diving_since_date')
          ? switch (calendarDay(values['diving_since_date'])) {
              final day? => DateTime(day.year),
              null => null,
            }
          : diver.divingSince,
      sex: values.containsKey('sex')
          ? DiverSex.values.asNameMap()[values['sex']]
          : diver.sex,
      birthYear: kept('birth_year', diver.birthYear),
    );
  }
}
